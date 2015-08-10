#!/bin/bash

# This is the 2nd version of CNTK recipe for AMI corpus.
# In this recipe, CNTK directly read Kaldi features and labels,
# which makes the whole pipline much simpler. Here, we only
# train the standard hybrid DNN model. To train LSTM and PAC-RNN
# models, you have to change the ndl file. -Liang (1/5/2015)

. ./cmd.sh
. ./path.sh

num_threads=1
device=1
train_epochs=50
epoch=30
stage=0
fbanksize=100
lrps=0.0001 #learning rate per sample for cntk
trsubsetsize=1000 # num utterances (head -n) considered for training
dtsubsetsize=500 # num utterances (head -n) considered for validation

LM=tgpr_5k

noisy_channels="1_3_4_5_6"
clean_channels="1_3_4_5_6"
refch="5"

noisy_type=ch
clean_type=reverb_ch

chime3_dir="/local_data2/watanabe/work/201410CHiME3/CHiME3" #MERL
#chime3_dir="/export/ws15-ffs-data/corpora/chime3/CHiME3" #JSALT

# CNTK config variables
start_from_scratch=false # delete experiment directory before starting the experiment
model=dnn_6layer_ce # {dnn_3layer,dnn_6layer,lstmp-3layer}
action=TrainLSTM # {TrainDNN, TrainLSTM}
cntk_config=CNTK2_lstm_ce_ed_complex_filter.config
config_write=CNTK2_write_ce_ed_complex_filter.config
nj=20
njdecode=4

hiddenDim=512
cellDim=1024
bottleneckDim=256
initModel=${model}.ndl
addLayerMel=${model}.mel
initModel=default.ndl
addLayerMel=default.mel

noisyfeatdir=data-fbank-${fbanksize}
noisystftdir=data-stft-real-imag
cleanstftdir=data-stft-real-imag

wavdir="/local_data2/watanabe/work/201410CHiME3/CHiME3/data/audio/16kHz" # MERL
#wavdir="/export/ws15-ffs-data2/herdogan/corpora/chime3/CHiME3/data/audio/16kHz" #JSALT

# starting from fbank beamforming sMBR alignments
enhan=beamformed_1sec_scwin_ch1_3-6
prevexpdir=$chime3_dir/tools/ASR_eval/exp/tri4a_dnn_tr05_multi_${enhan}_smbr_i1lats
prevexpgraphdir=$chime3_dir/tools/ASR_eval/exp/tri4a_dnn_tr05_multi_${enhan}
alidir_tr=exp/tri4a_dnn_tr05_multi_${enhan}_smbr_i1lats_ali
alidir_dt=exp/tri4a_dnn_tr05_multi_${enhan}_smbr_i1lats_ali_dt05

. parse_options.sh || exit 1;

# Set bash to 'debug' mode, it will exit on :
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',
set -e
set -u
set -o pipefail
set -x

output=ce_${noisy_type}${noisy_channels}_${model}
expdir=exp/cntk_${output}

if [ "$start_from_scratch" = true ]; then
 # restart the training from epoch 0,
 # so delete everything
 echo "Deleting the experiment directory $expdir, to restart training from scratch."
 rm -rf $expdir
fi

fbank_config=conf/fbank_${fbanksize}.conf
stft_config=conf/stft_real_imag.conf

cat << EOF > ${fbank_config}
--window-type=hamming # disable Dans window, use the standard
--use-energy=false    # only fbank outputs
--sample-frequency=16000 # Cantonese is sampled at 8kHz
--low-freq=64         # typical setup from Frantisek Grezl
--high-freq=8000
--dither=1
--frame-shift=10.0
--frame-length=25.0
--snip-edges=false
--num-mel-bins=${fbanksize}     # 8kHz so we use 15 bins
--htk-compat=true     # try to make it compatible with HTK
EOF

cat << EOF > ${stft_config}
--window-type=hamming # disable Dans window, use the standard
--sample-frequency=16000 # Cantonese is sampled at 8kHz
--frame-shift=10.0
--frame-length=25.0
--dither=0
--preemphasis-coefficient=0
--remove-dc-offset=false
--round-to-power-of-two=true
--snip-edges=false
--output_layout=block
EOF

# common data preparation
if [ $stage -le 0 ]; then
  local/clean_wsj0_data_prep.sh $chime3_dir/data/WSJ0
  local/wsj_prepare_dict.sh 
  local/simu_noisy_chime3_data_prep.sh $chime3_dir
  local/real_noisy_chime3_data_prep.sh $chime3_dir

fi

# noisy speech fbank feature extraction
if [ $stage -le 1 ]; then
  for ch in `echo $noisy_channels | tr "_" " "`; do
    noisyinput=${noisy_type}${ch}

    # fbank feature extraction
    fbankdir=fbank-${fbanksize}/$noisyinput
    mkdir -p $noisyfeatdir
    # simu data
    for dataset in dt05_simu et05_simu tr05_simu; do
      x=${dataset}_${noisyinput}
      if [ ! -d data/$x ]; then
	local/simu_enhan_chime3_data_prep.sh ${noisyinput} ${wavdir}/${noisyinput}
      fi
      utils/copy_data_dir.sh data/$x ${noisyfeatdir}/$x
      steps/make_fbank.sh --nj 10 --cmd "$train_cmd" --fbank-config ${fbank_config} \
	${noisyfeatdir}/$x exp/make_fbank/$x $fbankdir || exit 1;
    done
    # real data
    for dataset in dt05_real et05_real tr05_real; do
      x=${dataset}_${noisyinput}
      if [ ! -d data/$x ]; then
	local/real_enhan_chime3_data_prep.sh ${noisyinput} ${wavdir}/${noisyinput}
      fi
      utils/copy_data_dir.sh data/$x ${noisyfeatdir}/$x
      steps/make_fbank.sh --nj 10 --cmd "$train_cmd" --fbank-config ${fbank_config} \
	${noisyfeatdir}/$x exp/make_fbank/$x $fbankdir || exit 1;
    done
  done
fi

# noisy speech stft feature extraction
if [ $stage -le 2 ]; then
  for ch in `echo $noisy_channels | tr "_" " "`; do
    noisyinput=${noisy_type}${ch}

    # stft feature extraction
    stftndir=stft/real_imag/$noisyinput
    # simu data
    for dataset in dt05_simu et05_simu tr05_simu; do
      x=${dataset}_${noisyinput}
      if [ ! -d data/$x ]; then
	local/simu_enhan_chime3_data_prep.sh ${noisyinput} $wavdir/${noisyinput}
      fi
      utils/copy_data_dir.sh data/$x ${noisystftdir}/$x
      local/make_stft.sh --nj 10 --cmd "$train_cmd" --stft-config ${stft_config} \
	${noisystftdir}/$x exp/make_stft/$x $stftndir || exit 1;
    done
    # real data
    for dataset in dt05_real et05_real tr05_real; do
      x=${dataset}_${noisyinput}
      if [ ! -d data/$x ]; then
	local/real_enhan_chime3_data_prep.sh ${noisyinput} $wavdir/${noisyinput}
      fi
      utils/copy_data_dir.sh data/$x ${noisystftdir}/$x
      local/make_stft.sh --nj 10 --cmd "$train_cmd" --stft-config ${stft_config} \
	${noisystftdir}/$x exp/make_stft/$x $stftndir || exit 1;
    done
  done
fi

# clean speech stft feature extraction
if [ $stage -le 3 ]; then
  for ch in `echo $clean_channels | tr "_" " "`; do
    cleaninput=${clean_type}${ch}

    # stft feature extraction
    stftcdir=stft/real_imag/$cleaninput
    # only simu data
    for dataset in dt05_simu et05_simu tr05_simu; do
      y=${dataset}_${cleaninput}
      if [ ! -d data/$y ]; then
	local/simu_enhan_chime3_data_prep.sh ${cleaninput} $wavdir/${cleaninput}
      fi
      utils/copy_data_dir.sh data/$y ${cleanstftdir}/$y
      local/make_stft.sh --nj 10 --cmd "$train_cmd" --stft-config ${stft_config} \
	${cleanstftdir}/$y exp/make_stft/$y $stftcdir || exit 1;
    done
  done
fi

mkdir -p $expdir
# get alignment
if [ $stage -le 4 ]; then
  if [ ! -d ${alidir_tr} ]; then
    # make 40-dim fbank features for enhan data
    fbankdir=fbank/$enhan
    mkdir -p data-fbank
    for x in dt05_real_$enhan et05_real_$enhan tr05_real_$enhan dt05_simu_$enhan et05_simu_$enhan tr05_simu_$enhan; do
      cp -r $chime3_dir/tools/ASR_eval/data/$x data-fbank
      steps/make_fbank.sh --nj 10 --cmd "$train_cmd" --fbank-config conf/fbank_40.conf \
	data-fbank/$x exp/make_fbank/$x $fbankdir
    done
    # make mixed training set from real and simulation enhancement training data
    # multi = simu + real
    utils/combine_data.sh data-fbank/tr05_multi_$enhan data-fbank/tr05_simu_$enhan data-fbank/tr05_real_$enhan
    utils/combine_data.sh data-fbank/dt05_multi_$enhan data-fbank/dt05_simu_$enhan data-fbank/dt05_real_$enhan

    steps/nnet/align.sh --nj $nj --cmd "$train_cmd" \
      data-fbank/tr05_multi_${enhan} $chime3_dir/tools/ASR_eval/data/lang $prevexpdir ${alidir_tr}
    steps/nnet/align.sh --nj $njdecode --cmd "$train_cmd" \
      data-fbank/dt05_multi_${enhan} $chime3_dir/tools/ASR_eval/data/lang $prevexpdir ${alidir_dt}
  fi
fi

###### set input and output features for CNTK for each channel
if [ $stage -le 5 ]; then
  for ch in `echo $noisy_channels | tr "_" " "`; do
    noisyinput=${noisy_type}${ch}
    utils/combine_data.sh ${noisyfeatdir}/tr05_multi_${noisyinput} \
      ${noisyfeatdir}/tr05_simu_${noisyinput} ${noisyfeatdir}/tr05_real_${noisyinput}
    utils/combine_data.sh ${noisyfeatdir}/dt05_multi_${noisyinput} \
      ${noisyfeatdir}/dt05_simu_${noisyinput} ${noisyfeatdir}/dt05_real_${noisyinput}
    if [ ${trsubsetsize} -gt 0 ]; then
      utils/subset_data_dir.sh ${noisyfeatdir}/tr05_multi_${noisyinput} ${trsubsetsize} \
	${noisyfeatdir}/tr05_multi_${noisyinput}_${trsubsetsize}
      feats_tr="scp:${noisyfeatdir}/tr05_multi_${noisyinput}_${trsubsetsize}/feats.scp"
    else
      feats_tr="scp:${noisyfeatdir}/tr05_multi_${noisyinput}/feats.scp"
    fi
    if [ ${dtsubsetsize} -gt 0 ]; then
      utils/subset_data_dir.sh ${noisyfeatdir}/dt05_multi_${noisyinput} ${dtsubsetsize} \
	${noisyfeatdir}/dt05_multi_${noisyinput}_${dtsubsetsize}
      feats_dt="scp:${noisyfeatdir}/dt05_multi_${noisyinput}_${dtsubsetsize}/feats.scp"
    else
      feats_dt="scp:${noisyfeatdir}/dt05_multi_${noisyinput}/feats.scp"
    fi

    (feat-to-len "$feats_tr" ark,t:- > $expdir/cntk_train.$ch.counts) || exit 1;
    echo "$feats_tr" > $expdir/cntk_train.$ch.feats
    (feat-to-len "$feats_dt" ark,t:- > $expdir/cntk_valid.$ch.counts) || exit 1;
    echo "$feats_dt" > $expdir/cntk_valid.$ch.feats
  done

  for ch in `echo $noisy_channels | tr "_" " "`; do
    noisyinput=${noisy_type}${ch}
    utils/combine_data.sh ${noisystftdir}/tr05_multi_${noisyinput} \
      ${noisystftdir}/tr05_simu_${noisyinput} ${noisystftdir}/tr05_real_${noisyinput}
    utils/combine_data.sh ${noisystftdir}/dt05_multi_${noisyinput} \
      ${noisystftdir}/dt05_simu_${noisyinput} ${noisystftdir}/dt05_real_${noisyinput}
    if [ ${trsubsetsize} -gt 0 ]; then
      utils/subset_data_dir.sh ${noisystftdir}/tr05_multi_${noisyinput} ${trsubsetsize} \
        ${noisystftdir}/tr05_multi_${noisyinput}_${trsubsetsize}
      stftn_tr="scp:${noisystftdir}/tr05_multi_${noisyinput}_${trsubsetsize}/feats.scp"
    else
      stftn_tr="scp:${noisystftdir}/tr05_multi_${noisyinput}/feats.scp"
    fi
    if [ ${dtsubsetsize} -gt 0 ]; then
      utils/subset_data_dir.sh ${noisystftdir}/dt05_multi_${noisyinput} ${dtsubsetsize} \
        ${noisystftdir}/dt05_multi_${noisyinput}_${dtsubsetsize}
      stftn_dt="scp:${noisystftdir}/dt05_multi_${noisyinput}_${dtsubsetsize}/feats.scp"
    else
      stftn_dt="scp:${noisystftdir}/dt05_multi_${noisyinput}/feats.scp"
    fi

    echo "$stftn_tr" > $expdir/cntk_train.$ch.stftn
    echo "$stftn_dt" > $expdir/cntk_valid.$ch.stftn
  done

  for ch in `echo $clean_channels | tr "_" " "`; do
    cleaninput=${clean_type}${ch}
    stftc_tr="scp:${cleanstftdir}/tr05_simu_${cleaninput}/feats.scp"
    stftc_dt="scp:${cleanstftdir}/dt05_simu_${cleaninput}/feats.scp"

    echo "$stftc_tr" > $expdir/cntk_train.$ch.stftc
    echo "$stftc_dt" > $expdir/cntk_valid.$ch.stftc
  done
fi

###### set input and output stacking features for CNTK for all channels
if [ $stage -le 6 ]; then
  for dataset in dt05_real et05_real tr05_real dt05_simu et05_simu tr05_simu; do
    # noisy feature stacking
    if [ ! -d ${noisyfeatdir}/${dataset}_${noisy_type}${noisy_channels} ]; then
      echo -n "./steps/append_feats.sh " >  $expdir/stack_feat_${dataset}.sh
      for ch in `echo $noisy_channels | tr "_" " "`; do
	noisyinput=${noisy_type}${ch}
	x=${dataset}_${noisyinput}
	echo -n "${noisyfeatdir}/$x " >> $expdir/stack_feat_${dataset}.sh
      done
      echo -n "${noisyfeatdir}/${dataset}_${noisy_type}${noisy_channels} " >> $expdir/stack_feat_${dataset}.sh
      echo -n "$expdir/append_feat_${dataset}_${noisy_type}${noisy_channels} " >> $expdir/stack_feat_${dataset}.sh
      echo -n "fbank-${fbanksize}" >> $expdir/stack_feat_${dataset}.sh
      chmod +x $expdir/stack_feat_${dataset}.sh
      $expdir/stack_feat_${dataset}.sh
    fi
    # noisy stft stacking
    if [ ! -d ${noisystftdir}/${dataset}_${noisy_type}${noisy_channels} ]; then
      echo -n "./steps/append_feats.sh " >  $expdir/stack_stft_${dataset}.sh
      for ch in `echo $noisy_channels | tr "_" " "`; do
	noisyinput=${noisy_type}${ch}
	x=${dataset}_${noisyinput}
	echo -n "${noisystftdir}/$x " >> $expdir/stack_stft_${dataset}.sh
      done
      echo -n "${noisystftdir}/${dataset}_${noisy_type}${noisy_channels} " >> $expdir/stack_stft_${dataset}.sh
      echo -n "$expdir/append_stft_${dataset}_${noisy_type}${noisy_channels} " >> $expdir/stack_stft_${dataset}.sh
      echo -n "stft/real_imag/${noisy_type}" >> $expdir/stack_stft_${dataset}.sh
      chmod +x $expdir/stack_stft_${dataset}.sh
      $expdir/stack_stft_${dataset}.sh
    fi
  done

  utils/combine_data.sh ${noisyfeatdir}/tr05_multi_${noisy_type}${noisy_channels} \
    ${noisyfeatdir}/tr05_simu_${noisy_type}${noisy_channels} ${noisyfeatdir}/tr05_real_${noisy_type}${noisy_channels}
  utils/combine_data.sh ${noisyfeatdir}/dt05_multi_${noisy_type}${noisy_channels} \
    ${noisyfeatdir}/dt05_simu_${noisy_type}${noisy_channels} ${noisyfeatdir}/dt05_real_${noisy_type}${noisy_channels}
  if [ ${trsubsetsize} -gt 0 ]; then
    utils/subset_data_dir.sh ${noisyfeatdir}/tr05_multi_${noisy_type}${noisy_channels} ${trsubsetsize} \
      ${noisyfeatdir}/tr05_multi_${noisy_type}${noisy_channels}_${trsubsetsize}
    feats_tr="scp:${noisyfeatdir}/tr05_multi_${noisy_type}${noisy_channels}_${trsubsetsize}/feats.scp"
  else
    feats_tr="scp:${noisyfeatdir}/tr05_multi_${noisy_type}${noisy_channels}/feats.scp"
  fi
  if [ ${dtsubsetsize} -gt 0 ]; then
    utils/subset_data_dir.sh ${noisyfeatdir}/dt05_multi_${noisy_type}${noisy_channels} ${dtsubsetsize} \
      ${noisyfeatdir}/dt05_multi_${noisy_type}${noisy_channels}_${dtsubsetsize}
    feats_dt="scp:${noisyfeatdir}/dt05_multi_${noisy_type}${noisy_channels}_${dtsubsetsize}/feats.scp"
  else
    feats_dt="scp:${noisyfeatdir}/dt05_multi_${noisy_type}${noisy_channels}/feats.scp"
  fi
  echo "$feats_tr" > $expdir/cntk_train.stack.feats
  echo "$feats_dt" > $expdir/cntk_valid.stack.feats

  utils/combine_data.sh ${noisystftdir}/tr05_multi_${noisy_type}${noisy_channels} \
    ${noisystftdir}/tr05_simu_${noisy_type}${noisy_channels} ${noisystftdir}/tr05_real_${noisy_type}${noisy_channels}
  utils/combine_data.sh ${noisystftdir}/dt05_multi_${noisy_type}${noisy_channels} \
    ${noisystftdir}/dt05_simu_${noisy_type}${noisy_channels} ${noisystftdir}/dt05_real_${noisy_type}${noisy_channels}
  if [ ${trsubsetsize} -gt 0 ]; then
    utils/subset_data_dir.sh ${noisystftdir}/tr05_multi_${noisy_type}${noisy_channels} ${trsubsetsize} \
      ${noisystftdir}/tr05_multi_${noisy_type}${noisy_channels}_${trsubsetsize}
    stftn_tr="scp:${noisystftdir}/tr05_multi_${noisy_type}${noisy_channels}_${trsubsetsize}/feats.scp"
  else
    stftn_tr="scp:${noisystftdir}/tr05_multi_${noisy_type}${noisy_channels}/feats.scp"
  fi
  if [ ${dtsubsetsize} -gt 0 ]; then
    utils/subset_data_dir.sh ${noisystftdir}/dt05_multi_${noisy_type}${noisy_channels} ${dtsubsetsize} \
      ${noisystftdir}/dt05_multi_${noisy_type}${noisy_channels}_${dtsubsetsize}
    stftn_dt="scp:${noisystftdir}/dt05_multi_${noisy_type}${noisy_channels}_${dtsubsetsize}/feats.scp"
  else
    stftn_dt="scp:${noisystftdir}/dt05_multi_${noisy_type}${noisy_channels}/feats.scp"
  fi
  echo "$stftn_tr" > $expdir/cntk_train.stack.stftn
  echo "$stftn_dt" > $expdir/cntk_valid.stack.stftn

  # we did not make a subset of alignments
  labels_tr="ark:ali-to-pdf $alidir_tr/final.mdl \"ark:gunzip -c $alidir_tr/ali.*.gz |\" ark:- | ali-to-post ark:- ark:- |"
  labels_dt="ark:ali-to-pdf $alidir_dt/final.mdl \"ark:gunzip -c $alidir_dt/ali.*.gz |\" ark:- | ali-to-post ark:- ark:- |"
  echo "$labels_tr" > $expdir/cntk_train.labels
  echo "$labels_dt" > $expdir/cntk_valid.labels

  # noisy feature: stack
  # noisy and clean: ch5
  cp $expdir/cntk_train.stack.feats $expdir/cntk_train.feats
  cp $expdir/cntk_train.stack.stftn $expdir/cntk_train.stftn
  cp $expdir/cntk_train.${refch}.counts $expdir/cntk_train.counts

  cp $expdir/cntk_valid.stack.feats $expdir/cntk_valid.feats
  cp $expdir/cntk_valid.stack.stftn $expdir/cntk_valid.stftn
  cp $expdir/cntk_valid.${refch}.counts $expdir/cntk_valid.counts
fi


frame_context=7  # one sided context size (for DNN)
feats_tr=`cat $expdir/cntk_train.feats`
baseFeatDim=`feat-to-dim $feats_tr -`
featDim=`echo "$baseFeatDim * (2 * $frame_context + 1)"|bc`
stftn_tr=`cat $expdir/cntk_train.stftn`
allstftDim=`feat-to-dim $stftn_tr -`
stftc_tr=`cat $expdir/cntk_train.${refch}.stftn`
stftDim=`feat-to-dim $stftc_tr -`
hstftDim=`echo $stftDim/2|bc`
melDim=40
twicemelDim=`echo "$melDim * 2 " | bc`

# get mel matrix, 25: shift (ms), 16000 (sampling), 1 ((2 times number of contexts) + 1) times number of channels
local/write_kaldi_melmatrix.pl $melDim 25 16000 1 > $expdir/mel$melDim.mat

labelDim=`am-info $alidir_tr/final.mdl | grep "pdfs" | awk '{print $4;}'`
for (( c=0; c<labelDim; c++)) ; do
  echo $c
done >$expdir/cntk_label.mapping

#additional arguments for LSTM training, these are required to shift the features
frame_shift=5 # number of frames to shift the features
RowSliceStart=`echo "($frame_context + $frame_shift ) *  $baseFeatDim"|bc`

# stage 1 (TRAIN)
if [ $stage -le 7 ] ; then

### setup the configuration files for training CNTK models ###
cp cntk_config/${cntk_config} $expdir/${cntk_config}
cp cntk_config/default_macros.ndl $expdir/default_macros.ndl
cp cntk_config/${model}.ndl $expdir/${model}.ndl
#cp cntk_config/${addLayerMel} $expdir/${addLayerMel}
#cp cntk_config/${initModel} $expdir/${initModel}
ndlfile=$expdir/${model}.ndl

tee $expdir/Base.config <<EOF
ExpDir=$expdir
modelName=$expdir/cntk_model/cntk.dnn

hiddenDim=${hiddenDim}
cellDim=${cellDim}
bottleneckDim=${bottleneckDim}

initModel=${expdir}/${initModel}
addLayerMel=${expdir}/${addLayerMel}

baseFeatDim=$baseFeatDim
RowSliceStart=$RowSliceStart 
featDim=${featDim}
allstftDim=${allstftDim}
stftDim=${stftDim}
hstftDim=${hstftDim}
featureTransform=NO_FEATURE_TRANSFORM
lrps=${lrps}
trainEpochs=${train_epochs}
labelDim=${labelDim}
labelMapping=${expdir}/cntk_label.mapping

melDim=${melDim}
twicemelDim=${twicemelDim}
MelFileName=$expdir/mel$melDim.mat

action=${action}
ndlfile=$ndlfile
numThreads=$num_threads

inputCounts=${expdir}/cntk_train.counts
inputFeats=${expdir}/cntk_train.feats
inputStftn=${expdir}/cntk_train.stftn
inputStftc=${expdir}/cntk_train.stftc
inputLabels=${expdir}/cntk_train.labels

cvInputCounts=${expdir}/cntk_valid.counts
cvInputFeats=${expdir}/cntk_valid.feats
cvInputStftn=${expdir}/cntk_valid.stftn
cvInputStftc=${expdir}/cntk_valid.stftc
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

# stage 7 (enhance dev and test sets)
if [ $stage -le 8 ] ; then

  cp cntk_config/${config_write} $expdir/${config_write}
  cnmodel=$expdir/cntk_model/cntk.dnn.${epoch}
  action=write
  graphdir=$prevexpgraphdir/graph_${LM}
  cp $alidir_tr/final.mdl $expdir

  if [ -e $cnmodel ]; then
   echo "Enhancing with trained model from epoch ${epoch}"
 
   #for set in {dt05_simu,et05_simu}; do
   for dataset in dt05_real dt05_simu et05_real et05_simu; do
     datafeat=$noisyfeatdir/${dataset}_${noisy_type}${noisy_channels}
     datastft=$noisystftdir/${dataset}_${noisy_type}${noisy_channels}
     output_dir=$expdir/decode_graph_${LM}_${dataset}
     cntk_string="cntk configFile=${expdir}/${config_write} DeviceNumber=-1 modelName=$cnmodel featDim=$featDim stftDim=$stftDim hstftDim=$hstftDim labelDim=$labelDim allstftDim=${allstftDim} action=$action ExpDir=$expdir"
     # run in the background and use wait
     local/decode_cntk_2feat.sh --nj $njdecode --cmd "$decode_cmd" --num-threads ${num_threads} --parallel-opts '-pe smp 4' $graphdir $datafeat $datastft $output_dir "$cntk_string"
   done
   wait;
  else
     echo "$cnmodel not found. Try to specify another epoch number with --epoch"
  fi

fi

sleep 3
exit 0

