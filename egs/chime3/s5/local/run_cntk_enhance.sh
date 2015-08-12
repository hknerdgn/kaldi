#!/bin/bash

# This is the CNTK recipe chime3 speech enhancement
# In this recipe, CNTK directly reads Kaldi features and stfts

# Hakan Erdogan and Shinji Watanabe

. ./cmd.sh
. ./path.sh

num_threads=1
device=0
# training noisy-clean pairs
noisyinput=ch5
cleaninput=reverb_ch5
trsubsetsize=all # num utterances (head -n) considered for training
dtsubsetsize=all # num utterances (head -n) considered for validation
# test on which channel
noisytestinput=same # do not change this default, give a different one in command line if needed

stage=0
# feat extraction parameters
fbanksize=100
frameshift_ms=10
framelength_ms=25
fs=16000
rewrite_feats=false

# parallel jobs
njfeat=20
njenh=4

# CNTK config variables
start_from_scratch=false # delete experiment directory before starting the experiment
model=dnn_6layer_enh # {dnn_3layer,dnn_6layer,lstmp-3layer}
action=TrainDNN # {TrainDNN, TrainLSTM}
cntk_config=CNTK2_enh.config
config_write=CNTK2_write_enh.config

# you can give a modelvariety to train a different version of a model
# for example by changing framelength, input features or hiddenDim variables etc.
modelvariety=
# cntk model parameters passed to cntk by writing into Base.config
train_epochs=50
epoch=15 # test epoch, use epoch which gives lowest validation error
lrps=0.001 #learning rate per sample for cntk
hiddenDim=512
cellDim=1024
bottleneckDim=256
initModel=${model}.ndl
addLayerMel=${model}.mel

# wave files obtained from here
chime3dir=/local_data2/watanabe/work/201410CHiME3/CHiME3
chime3dir=/data2/erdogan/chime3

echo "$0 $@"  # Print the command line for logging

. parse_options.sh || exit 1;

wavdir=$chime3dir/data/audio/16kHz

if [ x$noisytestinput == "xsame" ]; then
  noisytestinput=$noisyinput
fi

output=enh_${noisyinput}_${model}${modelvariety} # for trained model

expdir=exp/cntk_${output}

fbankvariety=${fbanksize}_${framelength_ms}_${frameshift_ms}_${fs}
stftvariety=${framelength_ms}_${frameshift_ms}_${fs}
fbanklnkdir=data/fbank_${fbankvariety}
stftlnkdir=data/stft_${stftvariety}
fbankrawdir=dataraw/fbank_${fbankvariety}
stftrawdir=dataraw/stft_${stftvariety}

fbank_config=conf/fbank_${fbankvariety}.conf
stft_config=conf/stft_${stftvariety}.conf

# a bash function for making features
function make_feat {
  dset=$1 # dt05_real, tr05_real etc.
  input=$2 # channel or enhan or any variety of wav files
  ftype=$3 # fbank or stft
  fvariety=$4 # feature variety
  fconf=$5 # feature config file
  realsimu=$6 # real or simu
  rewrite=$7 # true or false
  featlnkdir=data/${ftype}_${fvariety}
  featrawdir=dataraw/${ftype}_${fvariety}
  x=${dset}_${input}
  if [ ! -d $featlnkdir/$x ] || [ ! -e $featrawdir/raw_${ftype}_${x}.1.ark ] || [ $rewrite == "true" ]; then
    mkdir -p $featlnkdir
    if [ ! -d data/$x ]; then
      if [ $realsimu == "real" ]; then
        local/real_enhan_chime3_data_prep.sh ${input} ${wavdir}/${input}
      elif [ $realsimu == "simu" ]; then
        local/simu_enhan_chime3_data_prep.sh ${input} ${wavdir}/${input}
      fi
    fi
    utils/copy_data_dir.sh data/$x ${featlnkdir}/$x
    mkdir -p $featrawdir
    if [ $ftype == "fbank" ]; then
      steps/make_fbank.sh --nj ${njfeat} --cmd "$train_cmd" --fbank-config ${fconf} \
        ${featlnkdir}/$x exp/make_fbank/$x $featrawdir || exit 1;
    elif [ $ftype == "stft" ]; then
      local/make_stft.sh  --nj ${njfeat} --cmd "$train_cmd" --stft-config  ${fconf} \
        ${featlnkdir}/$x exp/make_stft/$x  $featrawdir || exit 1;
    fi
  fi
}


cat << EOF > ${fbank_config}
--window-type=hamming # disable Dans window, use the standard
--use-energy=false    # only fbank outputs
--sample-frequency=${fs} # Cantonese is sampled at 8kHz
--low-freq=64         # typical setup from Frantisek Grezl
--high-freq=8000
--dither=1
--frame-shift=${frameshift_ms}
--frame-length=${framelength_ms}
--snip-edges=false
--num-mel-bins=${fbanksize}     # 8kHz so we use 15 bins
--htk-compat=true     # try to make it compatible with HTK
EOF

cat << EOF > ${stft_config}
--window-type=hamming # disable Dans window, use the standard
--sample-frequency=${fs} # Cantonese is sampled at 8kHz
--frame-shift=${frameshift_ms}
--frame-length=${framelength_ms}
--dither=0
--preemphasis-coefficient=0
--remove-dc-offset=false
--round-to-power-of-two=true
--snip-edges=false
--output_type=amplitude_and_phase
--output_layout=block
EOF

if [ $stage -le 0 ]; then

if [ "$start_from_scratch" == true ]; then
 # restart the training from epoch 0,
 # so delete everything
 echo "Deleting the experiment directory $expdir, to restart training from scratch."
 rm -rf $expdir
fi

# these make necessary files under data/$x
if [ ! -d data ] || [ ${rewrite_feats} == true ]; then
  local/clean_wsj0_data_prep.sh $chime3dir/data/WSJ0 || exit 1;
  local/wsj_prepare_dict.sh || exit 1;
  local/simu_noisy_chime3_data_prep.sh $chime3dir || exit 1;
  local/real_noisy_chime3_data_prep.sh $chime3dir || exit 1;
fi

# make fbank and stft features using the bash function defined above

for dataset in {tr05,dt05,et05}; do
  for datatype in {real,simu}; do
    make_feat ${dataset}_${datatype} ${noisyinput} fbank ${fbankvariety} ${fbank_config} ${datatype} ${rewrite_feats}
    make_feat ${dataset}_${datatype} ${noisyinput} stft  ${stftvariety}  ${stft_config}  ${datatype} ${rewrite_feats}
  done
done

# multi = simu + real
for dataset in {tr05,dt05,et05}; do
  if [ ! -d $fbanklnkdir/${dataset}_multi_$noisyinput ]; then
    utils/combine_data.sh $fbanklnkdir/${dataset}_multi_$noisyinput $fbanklnkdir/${dataset}_simu_$noisyinput ${fbanklnkdir}/${dataset}_real_$noisyinput
  fi
done

# make stft features for clean data , no real clean yet

for dataset in {tr05,dt05,et05}; do
  for env in simu; do
    make_feat ${dataset}_${env} ${cleaninput} stft  ${stftvariety}  ${stft_config}  ${env} ${rewrite_feats}
  done
done

fi # stage -le 0

######

# train and validate using simu data only

feats_tr="scp:${fbanklnkdir}/tr05_simu_${noisyinput}/feats.scp"
stftn_tr="scp:${stftlnkdir}/tr05_simu_${noisyinput}/feats.scp"
stftc_tr="scp:${stftlnkdir}/tr05_simu_${cleaninput}/feats.scp"

feats_dt="scp:${fbanklnkdir}/dt05_simu_${noisyinput}/feats.scp"
stftn_dt="scp:${stftlnkdir}/dt05_simu_${noisyinput}/feats.scp"
stftc_dt="scp:${stftlnkdir}/dt05_simu_${cleaninput}/feats.scp"

if [ x$trsubsetsize != "x" ] && [ x$trsubsetsize != "xall" ]; then

head -n $trsubsetsize ${fbanklnkdir}/tr05_simu_${noisyinput}/feats.scp > ${fbanklnkdir}/tr05_simu_${noisyinput}/feats_$trsubsetsize.scp
head -n $trsubsetsize ${stftlnkdir}/tr05_simu_${noisyinput}/feats.scp > ${stftlnkdir}/tr05_simu_${noisyinput}/feats_$trsubsetsize.scp
head -n $trsubsetsize ${stftlnkdir}/tr05_simu_${cleaninput}/feats.scp > ${stftlnkdir}/tr05_simu_${cleaninput}/feats_$trsubsetsize.scp
feats_tr="scp:${fbanklnkdir}/tr05_simu_${noisyinput}/feats_$trsubsetsize.scp"
stftn_tr="scp:${stftlnkdir}/tr05_simu_${noisyinput}/feats_$trsubsetsize.scp"
stftc_tr="scp:${stftlnkdir}/tr05_simu_${cleaninput}/feats_$trsubsetsize.scp"

fi

if [ x$dtsubsetsize != "x" ] && [ x$dtsubsetsize != "xall" ]; then

head -n $dtsubsetsize ${fbanklnkdir}/dt05_simu_${noisyinput}/feats.scp > ${fbanklnkdir}/dt05_simu_${noisyinput}/feats_$dtsubsetsize.scp
head -n $dtsubsetsize ${stftlnkdir}/dt05_simu_${noisyinput}/feats.scp > ${stftlnkdir}/dt05_simu_${noisyinput}/feats_$dtsubsetsize.scp
head -n $dtsubsetsize ${stftlnkdir}/dt05_simu_${cleaninput}/feats.scp > ${stftlnkdir}/dt05_simu_${cleaninput}/feats_$dtsubsetsize.scp
feats_dt="scp:${fbanklnkdir}/dt05_simu_${noisyinput}/feats_$dtsubsetsize.scp"
stftn_dt="scp:${stftlnkdir}/dt05_simu_${noisyinput}/feats_$dtsubsetsize.scp"
stftc_dt="scp:${stftlnkdir}/dt05_simu_${cleaninput}/feats_$dtsubsetsize.scp"

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
cellDim=${cellDim}
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


if [ -e $expdir/log/cntk.1.log ]; then
  tag=`date +%Y%m%d_%H%M%S`
  cp $expdir/log/cntk.1.log $expdir/log/prev.cntk.$tag.log
fi

$cntk_train_cmd $parallel_opts JOB=1:1 $expdir/log/cntk.JOB.log \
  cntk configFile=${expdir}/Base.config configFile=${expdir}/${cntk_config} DeviceNumber=$device

#if [ -e $expdir/log/cntk.1.log ]; then
#  tag=`date +%Y_%m_%d_%H_%M_%S`
#  mv $expdir/log/cntk.1.log $expdir/log/cntk.$tag.log
#fi

echo "$0 training (possibly) successfuly finished..."
echo "Model files are in $expdir/cntk_model"
echo "---------------"

fi

# stage 2 (enhance dev and test sets)
if [ $stage -le 2 ]; then

  if [ $noisytestinput != $noisyinput ]; then
    for dataset in {tr05,dt05,et05}; do
      for env in {real,simu}; do
        make_feat ${dataset}_${env} ${noisytestinput} fbank ${fbankvariety} ${fbank_config} ${env} ${rewrite}
        make_feat ${dataset}_${env} ${noisytestinput} stft  ${stftvariety}  ${stft_config}  ${env} ${rewrite}
      done
    done
  fi

  cp cntk_config/${config_write} $expdir/${config_write}
  cnmodel=$expdir/cntk_model/cntk.dnn.${epoch}
  action=write

  if [ -e $cnmodel ]; then
   echo "Enhancing with trained model from epoch ${epoch}"
 
   for dataset in {tr05_real,tr05_simu,dt05_real,dt05_simu,et05_real,et05_simu}; do
     datafeat=$fbanklnkdir/${dataset}_${noisytestinput}
     datastft=$stftlnkdir/${dataset}_${noisytestinput}
     enh_wav_dir=$expdir/enhance_${noisytestinput}_${epoch}  # output wavs will be written here
     cntk_string="cntk configFile=${expdir}/${config_write} DeviceNumber=-1 modelName=$cnmodel featDim=$featDim stftDim=$stftDim action=$action ExpDir=$expdir"
     # run in the background and use wait
     local/enhance_cntk.sh --stftconf $stft_config  --nj $njenh --cmd "$decode_cmd" --num-threads ${num_threads} --parallel-opts '-pe smp 4' $wavdir $datafeat $datastft ${enh_wav_dir} "$cntk_string" &
   done
   wait;
  else
     echo "$cnmodel not found. Try to specify another epoch number with --epoch"
  fi

fi

sleep 3
exit 0
