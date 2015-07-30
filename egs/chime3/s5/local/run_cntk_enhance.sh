#!/bin/bash

# This is the CNTK recipe chime3 speech enhancement
# In this recipe, CNTK directly reads Kaldi features and stfts

# Hakan Erdogan and Shinji Watanabe

. ./cmd.sh
. ./path.sh

num_threads=1
device=0
train_epochs=50
epoch=49 # test epoch
noisyinput=ch5
cleaninput=reverb_ch5
stage=0
fbanksize=100
lrps=0.001 #learning rate per sample for cntk
trsubsetsize=all # num utterances (head -n) considered for training
dtsubsetsize=all # num utterances (head -n) considered for validation

# CNTK config variables
start_from_scratch=false # delete experiment directory before starting the experiment
model=dnn_6layer_enh # {dnn_3layer,dnn_6layer,lstmp-3layer}
action=TrainDNN # {TrainDNN, TrainLSTM}
cntk_config=CNTK2_enh.config
config_write=CNTK2_write_enh.config
nj=20

hiddenDim=512
bottleneckDim=256
initModel=${model}.ndl
addLayerMel=${model}.mel

. parse_options.sh || exit 1;

noisyfeatdir=data-fbank-${fbanksize}/$noisyinput
cleanstftdir=data-stft/$cleaninput
noisystftdir=data-stft/$noisyinput

output=enh_${noisyinput}_${model}

expdir=exp/cntk_${output}

fbankdir=fbank-${fbanksize}/$noisyinput
stftndir=stft/$noisyinput
stftcdir=stft/$cleaninput
wavdir="/local_data2/watanabe/work/201410CHiME3/CHiME3/data/audio/16kHz"
fbank_config=conf/fbank_${fbanksize}.conf
stft_config=conf/stft.conf

if [ $stage -le 0 ]; then

if [ "$start_from_scratch" = true ]; then
 # restart the training from epoch 0,
 # so delete everything
 echo "Deleting the experiment directory $expdir, to restart training from scratch."
 rm -rf $expdir
fi


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
--output_type=amplitude_and_phase
--output_layout=block
EOF

if [ ! -d $fbankdir ]; then

local/clean_wsj0_data_prep.sh /local_data2/watanabe/work/201410CHiME3/CHiME3/data/WSJ0
local/simu_noisy_chime3_data_prep.sh /local_data2/watanabe/work/201410CHiME3/CHiME3

mkdir -p $noisyfeatdir
for dataset in dt05_simu et05_simu tr05_simu; do
  x=${dataset}_${noisyinput}
  if [ ! -d data/$x ]; then
	local/simu_enhan_chime3_data_prep.sh ${noisyinput} ${wavdir}/${noisyinput}
  fi
  utils/copy_data_dir.sh data/$x ${noisyfeatdir}/$x
  steps/make_fbank.sh --nj 10 --cmd "$train_cmd" --fbank-config ${fbank_config} \
    ${noisyfeatdir}/$x exp/make_fbank/$x $fbankdir || exit 1;
done

for dataset in dt05_real et05_real tr05_real; do
  x=${dataset}_${noisyinput}
  if [ ! -d data/$x ]; then
	local/real_enhan_chime3_data_prep.sh ${noisyinput} ${wavdir}/${noisyinput}
  fi
  utils/copy_data_dir.sh data/$x ${noisyfeatdir}/$x
  steps/make_fbank.sh --nj 10 --cmd "$train_cmd" --fbank-config ${fbank_config} \
    ${noisyfeatdir}/$x exp/make_fbank/$x $fbankdir || exit 1;
done

fi

if [ ! -d $noisystftdir ] || [ ! -d $stftndir ]; then

for dataset in dt05_simu et05_simu tr05_simu; do
  x=${dataset}_${noisyinput}
  if [ ! -d data/$x ]; then
	local/simu_enhan_chime3_data_prep.sh ${noisyinput} $wavdir/${noisyinput}
  fi
  utils/copy_data_dir.sh data/$x ${noisystftdir}/$x
  local/make_stft.sh --nj 10 --cmd "$train_cmd" --stft-config ${stft_config} \
    ${noisystftdir}/$x exp/make_stft/$x $stftndir || exit 1;
done

for dataset in dt05_real et05_real tr05_real; do
  x=${dataset}_${noisyinput}
  if [ ! -d data/$x ]; then
	local/real_enhan_chime3_data_prep.sh ${noisyinput} $wavdir/${noisyinput}
  fi
  utils/copy_data_dir.sh data/$x ${noisystftdir}/$x
  local/make_stft.sh --nj 10 --cmd "$train_cmd" --stft-config ${stft_config} \
    ${noisystftdir}/$x exp/make_stft/$x $stftndir || exit 1;
done

# make mixed training set from real and simulation noisy and clean training data
# multi = simu + real
utils/combine_data.sh data-fbank/tr05_multi_$noisyinput data-fbank/tr05_simu_$noisyinput data-fbank/tr05_real_$noisyinput
utils/combine_data.sh data-fbank/dt05_multi_$noisyinput data-fbank/dt05_simu_$noisyinput data-fbank/dt05_real_$noisyinput
utils/combine_data.sh data-fbank/et05_multi_$noisyinput data-fbank/et05_simu_$noisyinput data-fbank/et05_real_$noisyinput

fi

if [ ! -d $cleanstftdir ] || [ ! -d $stftcdir ]; then

# clean data only available for simulated data (for now)
for dataset in dt05_simu et05_simu tr05_simu; do
  y=${dataset}_${cleaninput}
  if [ ! -d data/$y ]; then
	local/simu_enhan_chime3_data_prep.sh ${cleaninput} $wavdir/${cleaninput}
  fi
  utils/copy_data_dir.sh data/$y ${cleanstftdir}/$y
  local/make_stft.sh --nj 10 --cmd "$train_cmd" --stft-config ${stft_config} \
    ${cleanstftdir}/$y exp/make_stft/$y $stftcdir || exit 1;
done

#utils/combine_data.sh data-fbank/tr05_multi_$cleaninput data-fbank/tr05_simu_$cleaninput data-fbank/tr05_real_$cleaninput
#utils/combine_data.sh data-fbank/dt05_multi_$cleaninput data-fbank/dt05_simu_$cleaninput data-fbank/dt05_real_$cleaninput
#utils/combine_data.sh data-fbank/et05_multi_$cleaninput data-fbank/et05_simu_$cleaninput data-fbank/et05_real_$cleaninput

fi

fi # stage -le 0

######

feats_tr="scp:${noisyfeatdir}/tr05_simu_${noisyinput}/feats.scp"
stftn_tr="scp:${noisystftdir}/tr05_simu_${noisyinput}/feats.scp"
stftc_tr="scp:${cleanstftdir}/tr05_simu_${cleaninput}/feats.scp"

feats_dt="scp:${noisyfeatdir}/dt05_simu_${noisyinput}/feats.scp"
stftn_dt="scp:${noisystftdir}/dt05_simu_${noisyinput}/feats.scp"
stftc_dt="scp:${cleanstftdir}/dt05_simu_${cleaninput}/feats.scp"

if [ x$trsubsetsize != "x" ] && [ x$trsubsetsize != "xall" ]; then

head -n $trsubsetsize ${noisyfeatdir}/tr05_simu_${noisyinput}/feats.scp > ${noisyfeatdir}/tr05_simu_${noisyinput}/feats_$trsubsetsize.scp
head -n $trsubsetsize ${noisystftdir}/tr05_simu_${noisyinput}/feats.scp > ${noisystftdir}/tr05_simu_${noisyinput}/feats_$trsubsetsize.scp
head -n $trsubsetsize ${cleanstftdir}/tr05_simu_${cleaninput}/feats.scp > ${cleanstftdir}/tr05_simu_${cleaninput}/feats_$trsubsetsize.scp
feats_tr="scp:${noisyfeatdir}/tr05_simu_${noisyinput}/feats_$trsubsetsize.scp"
stftn_tr="scp:${noisystftdir}/tr05_simu_${noisyinput}/feats_$trsubsetsize.scp"
stftc_tr="scp:${cleanstftdir}/tr05_simu_${cleaninput}/feats_$trsubsetsize.scp"

fi

if [ x$dtsubsetsize != "x" ] && [ x$dtsubsetsize != "xall" ]; then

head -n $dtsubsetsize ${noisyfeatdir}/dt05_simu_${noisyinput}/feats.scp > ${noisyfeatdir}/dt05_simu_${noisyinput}/feats_$dtsubsetsize.scp
head -n $dtsubsetsize ${noisystftdir}/dt05_simu_${noisyinput}/feats.scp > ${noisystftdir}/dt05_simu_${noisyinput}/feats_$dtsubsetsize.scp
head -n $dtsubsetsize ${cleanstftdir}/dt05_simu_${cleaninput}/feats.scp > ${cleanstftdir}/dt05_simu_${cleaninput}/feats_$dtsubsetsize.scp
feats_dt="scp:${noisyfeatdir}/dt05_simu_${noisyinput}/feats_$dtsubsetsize.scp"
stftn_dt="scp:${noisystftdir}/dt05_simu_${noisyinput}/feats_$dtsubsetsize.scp"
stftc_dt="scp:${cleanstftdir}/dt05_simu_${cleaninput}/feats_$dtsubsetsize.scp"

fi

frame_context=7  # one sided context size (for DNN)
baseFeatDim=`feat-to-dim ${feats_tr} -`
featDim=`echo "$baseFeatDim * (2 * $frame_context + 1)"|bc`
stftDim=`feat-to-dim ${stftn_tr} -`
hstftDim=`echo $stftDim/2|bc`

#additional arguments for LSTM training, these are required to shift the features
frame_shift=5 # number of frames to shift the features
RowSliceStart=`echo "($frame_context + $frame_shift ) *  $baseFeatDim"|bc`

mkdir -p $expdir

# stage 0 (PREP)
if [ $stage -le 0 ] ; then

(feat-to-len "$feats_tr" ark,t:- > $expdir/cntk_train.counts) || exit 1;
echo "$feats_tr" > $expdir/cntk_train.feats
echo "$stftn_tr" > $expdir/cntk_train.stftn
echo "$stftc_tr" > $expdir/cntk_train.stftc

(feat-to-len "$feats_dt" ark,t:- > $expdir/cntk_valid.counts) || exit 1;
echo "$feats_dt" > $expdir/cntk_valid.feats
echo "$stftn_dt" > $expdir/cntk_valid.stftn
echo "$stftc_dt" > $expdir/cntk_valid.stftc

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

baseFeatDim=$baseFeatDim
RowSliceStart=$RowSliceStart 
featDim=${featDim}
stftDim=${stftDim}
hstftDim=${hstftDim}
featureTransform=NO_FEATURE_TRANSFORM
lrps=${lrps}
trainEpochs=${train_epochs}

DeviceNumber=$device
action=${action}
ndlfile=$ndlfile
numThreads=$num_threads

inputCounts=${expdir}/cntk_train.counts
inputFeats=${expdir}/cntk_train.feats
inputStftn=${expdir}/cntk_train.stftn
inputStftc=${expdir}/cntk_train.stftc

cvInputCounts=${expdir}/cntk_valid.counts
cvInputFeats=${expdir}/cntk_valid.feats
cvInputStftn=${expdir}/cntk_valid.stftn
cvInputStftc=${expdir}/cntk_valid.stftc
EOF

## training command ##
mkdir -p $expdir/log/
parallel_opts=
if [ $num_threads -gt 1 ]; then
  parallel_opts="--num-threads $num_threads"
fi


$cntk_train_cmd $parallel_opts JOB=1:1 $expdir/log/cntk.JOB.log \
  cntk configFile=${expdir}/Base.config configFile=${expdir}/${cntk_config}

echo "$0 training successfuly finished.. $dir"

fi

# stage 2 (enhance dev and test sets)
if [ $stage -le 2 ] ; then

  cp cntk_config/${config_write} $expdir/${config_write}
  cnmodel=$expdir/cntk_model/cntk.dnn.${epoch}
  action=write

  for set in {dt05_real,dt05_simu,et05_real,et05_simu}; do
    datafeat=$noisyfeatdir/${set}_${noisyinput}
    datastft=$noisystftdir/${set}_${noisyinput}
    cntk_string="cntk configFile=${expdir}/${config_write} DeviceNumber=-1 modelName=$cnmodel featDim=$featDim stftDim=$stftDim hstftDim=$hstftDim action=$action ExpDir=$expdir"
    # run in the background and use wait
    local/enhance_cntk.sh --stftconf $stft_config  --nj $nj --cmd "$decode_cmd" --num-threads ${num_threads} --parallel-opts '-pe smp 4' $wavdir $datafeat $datastft $expdir/enhance_${set}_${epoch} "$cntk_string" &
  done
  wait;

fi

sleep 3
exit 0

