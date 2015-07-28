#!/bin/bash

# This is the 2nd version of CNTK recipe for AMI corpus.
# In this recipe, CNTK directly read Kaldi features and labels,
# which makes the whole pipline much simpler. Here, we only
# train the standard hybrid DNN model. To train LSTM and PAC-RNN
# models, you have to change the ndl file. -Liang (1/5/2015)

. ./cmd.sh
. ./path.sh

num_threads=1
device=0
epoch=30
enhan=isolated_beamformed_1sec_scwin_ch1_3-6
stage=0
datadir=data-fbank/$enhan
prevexp=tri3b_tr05_multi
LM=tgpr_5k

# CNTK config variables
start_from_scratch=false # delete experiment directory before starting the experiment
model=dnn_6layer # {dnn_3layer,dnn_6layer,lstmp-3layer}
action=TrainDNN # {TrainDNN, TrainLSTM}
cntk_config=CNTK2.config
config_write=CNTK2_write.config
nj=20

hiddenDim=512
bottleneckDim=256
initModel=default.ndl
addLayerMel=default.mel

. parse_options.sh || exit 1;

expdir=exp/cntk_${model}_${enhan}

alidir_tr=exp/${prevexp}_${enhan}_ali
alidir_dt=exp/${prevexp}_${enhan}_ali_dt05

if [ $stage -le 0 ]; then

# check whether run_init is executed
if [ ! -d data/lang ]; then
  echo "error, execute local/run_init.sh, first"
  exit 1;
fi

# check whether run_init is executed
if [ ! -d exp/${prevexp}_$enhan ]; then
  echo "error, execute local/run_gmm.sh or similar to get ${prevexp}, first"
  exit 1;
fi

if [ "$start_from_scratch" = true ]; then
 # restart the training from epoch 0,
 # so delete everything
 echo "Deleting the experiment directory $expdir, to restart training from scratch."
 rm -rf $expdir
fi


# make 40-dim fbank features for enhan data
if [ ! -d fbank/$enhan ]; then
fbankdir=fbank/$enhan
mkdir -p data-fbank
for x in dt05_real_$enhan et05_real_$enhan tr05_real_$enhan dt05_simu_$enhan et05_simu_$enhan tr05_simu_$enhan; do
  cp -r data/$x data-fbank
  steps/make_fbank.sh --nj 10 --cmd "$train_cmd" \
    data-fbank/$x exp/make_fbank/$x $fbankdir || exit 1;
done

# make mixed training set from real and simulation enhancement training data
# multi = simu + real
utils/combine_data.sh data-fbank/tr05_multi_$enhan data-fbank/tr05_simu_$enhan data-fbank/tr05_real_$enhan
utils/combine_data.sh data-fbank/dt05_multi_$enhan data-fbank/dt05_simu_$enhan data-fbank/dt05_real_$enhan
utils/combine_data.sh data-fbank/et05_multi_$enhan data-fbank/et05_simu_$enhan data-fbank/et05_real_$enhan
fi


if [ ! -d exp/${prevexp}_${enhan}_ali ]; then
# get alignment
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" \
  data/tr05_multi_$enhan data/lang exp/${prevexp}_$enhan ${alidir_tr} || exit 1;
steps/align_fmllr.sh --nj 4 --cmd "$train_cmd" \
  data/dt05_multi_$enhan data/lang exp/${prevexp}_$enhan ${alidir_dr} || exit 1;
fi

fi
######

feats_tr="scp:data-fbank/tr05_multi_$enhan/feats.scp"
feats_dt="scp:data-fbank/dt05_multi_$enhan/feats.scp"
labels_tr="ark:ali-to-pdf $alidir_tr/final.mdl \"ark:gunzip -c $alidir_tr/ali.*.gz |\" ark:- | ali-to-post ark:- ark:- |"
labels_dt="ark:ali-to-pdf $alidir_dt/final.mdl \"ark:gunzip -c $alidir_dt/ali.*.gz |\" ark:- | ali-to-post ark:- ark:- |"

labelDim=`am-info $alidir_tr/final.mdl | grep "pdfs" | awk '{print $4;}'`

frame_context=15
baseFeatDim=`feat-to-dim ${feats_tr} -`
featDim=`echo "$baseFeatDim * $frame_context"|bc`

#additional arguments for LSTM training, these are required to shift the features
frame_shift=5 # number of frames to shift the features
RowSliceStart=`echo "$baseFeatDim * 2 * $frame_shift"|bc`

mkdir -p $expdir

# stage 0 (PREP)
if [ $stage -le 0 ] ; then

(feat-to-len "$feats_tr" ark,t:- > $expdir/cntk_train.counts) || exit 1;
echo "$feats_tr" > $expdir/cntk_train.feats
echo "$labels_tr" > $expdir/cntk_train.labels

(feat-to-len "$feats_dt" ark,t:- > $expdir/cntk_valid.counts) || exit 1;
echo "$feats_dt" > $expdir/cntk_valid.feats
echo "$labels_dt" > $expdir/cntk_valid.labels

for (( c=0; c<labelDim; c++)) ; do
  echo $c
done >$expdir/cntk_label.mapping

fi

# stage 1 (TRAIN)
if [ $stage -le 1 ] ; then

### setup the configuration files for training CNTK models ###
cp cntk_config/${cntk_config} $expdir/${cntk_config}
cp cntk_config/default_macros.ndl $expdir/default_macros.ndl
cp cntk_config/${model}.ndl $expdir/${model}.ndl
cp cntk_config/${addLayerMel} $expdir/${addLayerMel}
cp cntk_config/${initModel} $expdir/${initModel}
ndlfile=$expdir/${model}.ndl

tee $expdir/Base.config <<EOF
ExpDir=$expdir
modelName=$expdir/cntk_model/cntk.dnn

hiddenDim=${hiddenDim}
bottleneckDim=${bottleneckDim}

initModel=${expdir}/${initModel}
addLayerMel=${expdir}/${addLayerMel}

labelDim=${labelDim}
featDim=${featDim}
labelMapping=${expdir}/cntk_label.mapping
featureTransform=NO_FEATURE_TRANSFORM

inputCounts=${expdir}/cntk_train.counts
inputFeats=${expdir}/cntk_train.feats
inputLabels=${expdir}/cntk_train.labels

cvInputCounts=${expdir}/cntk_valid.counts
cvInputFeats=${expdir}/cntk_valid.feats
cvInputLabels=${expdir}/cntk_valid.labels
EOF

## training command ##
mkdir -p $expdir/log/
parallel_opts=
if [ $num_threads -gt 1 ]; then
  parallel_opts="--num-threads $num_threads"
fi


$cntk_train_cmd $parallel_opts JOB=1:1 $expdir/log/cntk.JOB.log \
  cntk configFile=${expdir}/Base.config configFile=${expdir}/${cntk_config} \
  baseFeatDim=$baseFeatDim RowSliceStart=$RowSliceStart \
  DeviceNumber=$device action=${action} ndlfile=$ndlfile numThreads=$num_threads

echo "$0 successfuly finished.. $dir"

fi

# stage 2 (DECODE)
if [ $stage -le 2 ] ; then

  cp cntk_config/${config_write} $expdir/${config_write}
  cnmodel=$expdir/cntk_model/cntk.dnn.${epoch}
  action=write
  graphdir=exp/${prevexp}_${enhan}/graph_${LM}
  cp $alidir_tr/final.mdl $expdir

  for set in {dt05_real,dt05_simu,et05_real,et05_simu}; do
    dataset=data-fbank/${set}_${enhan}
    cntk_string="cntk configFile=${expdir}/${config_write} DeviceNumber=-1 modelName=$cnmodel labelDim=$labelDim featDim=$featDim action=$action ExpDir=$expdir"
    njdec=`cat $dataset/spk2utt|wc -l`
    # run in the background and use wait
    local/decode_cntk.sh  --nj $njdec --cmd "$decode_cmd" --num-threads ${num_threads} --parallel-opts '-pe smp 4' --acwt 0.0833 $graphdir $dataset $expdir/decode_${LM}_${set}_${enhan}_${epoch} "$cntk_string" &
  done
  wait;

fi


sleep 3
exit 0

