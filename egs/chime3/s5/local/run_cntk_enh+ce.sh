#!/bin/bash

# kaldi+CNTK recipe for enhancement/beamforming and CE training
# CNTK directly reads kaldi noisy signal stfts as input and reads and uses 
# clean stfts and labels for output targets
# Mel-filtering should be done within the ndl model
# we write both enhanced STFTs and scaled log-likelihoods for labels
# Hakan Erdogan and Shinji Watanabe

. ./cmd.sh
. ./path.sh

num_threads=1
device=0
train_epochs=50
epoch=30 # for testing
stage=0
lrps=0.001 #learning rate per sample for cntk

noisy_channels="1_3_4_5_6"
clean_channels="5"
order_of_target_ch=4

# options are stftamp, stftphase, fbank, mfcc, labels etc.
noisy_feat_types=stftamp_stftphase
clean_feat_types=stftamp_stftphase_labels

# all noisy feats are concatenated separately across frames, clean feats are single frame
frame_context=0  # one sided context size (for DNN)
frame_shift=0 # number of frames to shift the features (for LSTM)

noisy_type=ch
clean_type=reverb_ch


# CNTK config variables
start_from_scratch=false # delete experiment directory before starting the experiment
model=lstmp_enh2_ce2 # {dnn_3layer,dnn_6layer,lstmp-3layer}
modeltype=RNN # or DNN
memFrames=500000  # this is randomize parameter for cntk, limits the number of frames read
#config_write=CNTK2_write_enh+ce.config
nj=20
njspk=4

enhHiddenDim=512
ceHiddenDim=512
enhCellDim=1024
ceCellDim=1024
initFromModel=
initModel=
addLayerMel=

# the dimensions for filterbanks to be made within the ndl file
enhFeatDim=100
ceFeatDim=40
twoCeFeatDim=80

# you can give a modelvariety to train a different version of a model
# for example by changing framelength, input features or hiddenDim variables etc.
modelvariety=
# cntk model parameters passed to cntk by writing into Base.config
train_epochs=50
epoch=15 # test epoch, use epoch which gives lowest validation error
lrps=0.001 #learning rate per sample for cntk
rewrite=true

# wave files obtained from here
chime3_dir="/local_data2/watanabe/work/201410CHiME3/CHiME3"
chime3_dir="/export/ws15-ffs-data2/herdogan/corpora/chime3/CHiME3"

# feature extraction parameters
frameshift_ms=10
framelength_ms=25
fs=16000
fbanksize=100

# prevexp for alignment
prevexp=tri4a_dnn_tr05_multi
LM=tgpr_5k
bestdata=beamformed_1sec_scwin_ch1_3-6_smbr_i1lats

echo "$0 $@"  # Print the command line for logging

. parse_options.sh || exit 1;

alidir_tr=exp/${prevexp}_${bestdata}_ali
alidir_dt=exp/${prevexp}_${bestdata}_ali_dt05

# a hash array
declare -A featurevariety

if [ $modeltype == "RNN" ]; then
  action=trainRNN # {train, trainRNN}
  frameMode=false
  truncated=true
  prlUtt=50
  minibatchsize=40
elif [ $modeltype == "DNN" ]; then
  action=train # {train, trainRNN}
  frameMode=true
  truncated=false
  prlUtt=1
  minibatchsize=256
fi

# Set bash to 'debug' mode, it will exit on :
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',
set -e
set -u
set -o pipefail
set -x

wavdir=$chime3_dir/data/audio/16kHz

num_noisy_channels=0
for ch in `echo $noisy_channels | tr "_" " "`; do
  num_noisy_channels=`echo ${num_noisy_channels}+1 | bc`
done

num_clean_channels=0
for ch in `echo $clean_channels | tr "_" " "`; do
  num_clean_channels=`echo ${num_clean_channels}+1 | bc`
done

echo "Num noisy channels: ${num_noisy_channels}"
echo "Num clean channels: ${num_clean_channels}"

num_rep_noisy=`echo 2*${frame_context}*${num_noisy_channels}+${num_noisy_channels} | bc`
num_rep_clean=`echo 2*${frame_context}*${num_clean_channels}+${num_clean_channels} | bc`

echo "Num repeats noisy: ${num_rep_noisy}"
echo "Num repeats clean: ${num_rep_clean}"

enhMelFileName=cntk_config/Mel${enhFeatDim}_${num_rep_noisy}.txt
EnhMelNeedGradient=false
ceMelFileName=cntk_config/Mel${ceFeatDim}_${num_rep_clean}.txt
CeMelNeedGradient=false

if [ ! -e $enhMelFileName ]; then
   local/write_kaldi_melmatrix.pl ${enhFeatDim} ${framelength_ms} ${fs} ${num_rep_noisy} > $enhMelFileName
fi

if [ ! -e $ceMelFileName ]; then
   local/write_kaldi_melmatrix.pl ${ceFeatDim} ${framelength_ms} ${fs} ${num_rep_clean} > $ceMelFileName
fi

enhStackFeatDim=`echo "$enhFeatDim * ${num_rep_noisy}" | bc -l`

# write feat configs
for feat in `echo "${noisy_feat_types}_${clean_feat_types}" | tr "_" " "`; do
  if [ $feat == "stftamp" ]; then
    featurevariety[$feat]=${frameshift_ms}_${framelength_ms}_${fs}
    fvariety=${featurevariety[$feat]}
    feat_config=conf/${feat}_${fvariety}
    cat << EOF > ${feat_config}
--window-type=hamming # disable Dans window, use the standard
--sample-frequency=${fs} # Cantonese is sampled at 8kHz
--frame-shift=${frameshift_ms}
--frame-length=${framelength_ms}
--dither=0
--preemphasis-coefficient=0
--remove-dc-offset=false
--round-to-power-of-two=true
--snip-edges=false
--output_type=amplitude
--output_layout=block
EOF
  elif [ $feat == "stftphase" ]; then
    featurevariety[$feat]=${frameshift_ms}_${framelength_ms}_${fs}
    fvariety=${featurevariety[$feat]}
    feat_config=conf/${feat}_${fvariety}
    cat << EOF > ${feat_config}
--window-type=hamming # disable Dans window, use the standard
--sample-frequency=${fs} # Cantonese is sampled at 8kHz
--frame-shift=${frameshift_ms}
--frame-length=${framelength_ms}
--dither=0
--preemphasis-coefficient=0
--remove-dc-offset=false
--round-to-power-of-two=true
--snip-edges=false
--output_type=phase
--output_layout=block
EOF
  elif [ $feat == "fbank" ]; then
    featurevariety[$feat]=${frameshift_ms}_${framelength_ms}_${fs}_${fbanksize}
    fvariety=${featurevariety[$feat]}
    feat_config=conf/${feat}_${fvariety}
    cat << EOF > ${feat_config}
--window-type=hamming # disable Dan's window, use the standard
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
  fi
done

modelvariety=${lrps}
output=enh_${noisy_type}${noisy_channels}_${model}_${modelvariety}
expdir=exp/cntk_${output}

if [ "$start_from_scratch" = true ]; then
 # restart the training from epoch 0,
 # so delete everything
 echo "Deleting the experiment directory $expdir, to restart training from scratch."
 rm -rf $expdir
fi

# common data preparation
if [ $stage -le 0 ] && [ $rewrite == "true" ]; then
  local/clean_wsj0_data_prep.sh $chime3_dir/data/WSJ0
  local/wsj_prepare_dict.sh 
  local/simu_noisy_chime3_data_prep.sh $chime3_dir
  local/real_noisy_chime3_data_prep.sh $chime3_dir
fi

# noisy speech feature extraction
if [ $stage -le 2 ]; then
for feat in `echo "${noisy_feat_types}" | tr "_" " "`; do
  fvariety=${featurevariety[$feat]}
  fconf=conf/${feat}_${fvariety}
  for ch in `echo $noisy_channels | tr "_" " "`; do
    noisyinput=${noisy_type}${ch}
    for dataset in dt05 et05 tr05; do
      local/make_feat.sh --cmd "${train_cmd}" --rewrite ${rewrite} --nj ${nj} --wavdir $wavdir ${dataset}_simu $noisyinput $feat $fvariety $fconf simu 
      local/make_feat.sh --cmd "${train_cmd}" --rewrite ${rewrite} --nj ${nj} --wavdir $wavdir ${dataset}_real $noisyinput $feat $fvariety $fconf real
      ddir=data/${feat}_${fvariety}
      utils/combine_data.sh ${ddir}/${dataset}_multi_$noisyinput $ddir/${dataset}_simu_$noisyinput $ddir/${dataset}_real_$noisyinput
    done # dataset
  done # ch
done # feat

fi # stage -le 2

# clean speech feature extraction
if [ $stage -le 3 ]; then
for feat in `echo "${clean_feat_types}" | tr "_" " "`; do
  if [ $feat == "labels" ]; then
    continue
  fi
  fvariety=${featurevariety[$feat]}
  fconf=conf/${feat}_${fvariety}
  for ch in `echo $clean_channels | tr "_" " "`; do
    cleaninput=${clean_type}${ch}
    for dataset in dt05 et05 tr05; do
      local/make_feat.sh --cmd "${train_cmd}" --rewrite ${rewrite} --nj ${nj} --wavdir $wavdir ${dataset}_simu $cleaninput $feat $fvariety $fconf simu 
      #local/make_feat.sh --cmd "${train_cmd}" --rewrite ${rewrite} --nj ${nj} --wavdir $wavdir ${dataset}_real $cleaninput $feat $fvariety $fconf real
      #ddir=data/${feat}_${fvariety}
      #utils/combine_data.sh ${ddir}/${dataset}_multi_$cleaninput $ddir/${dataset}_simu_$cleaninput $ddir/${dataset}_real_$cleaninput
    done # dataset
  done # ch
done # feat

fi # stage -le 3

# end feature extraction

mkdir -p $expdir

###### set input and output features for CNTK
if [ $stage -le 4 ]; then
  for feat in `echo "${noisy_feat_types}" | tr "_" " "`; do
    for ch in `echo $noisy_channels | tr "_" " "`; do
      fvariety=${featurevariety[$feat]}
      noisyinput=${noisy_type}${ch}
      # change from simu to multi for cross-entropy tasks
      feat_tr="scp:data/${feat}_${fvariety}/tr05_simu_${noisyinput}/feats.scp"
      feat_dt="scp:data/${feat}_${fvariety}/dt05_simu_${noisyinput}/feats.scp"
      echo "$feat_tr" > $expdir/cntk_train.$noisyinput.${feat}_${fvariety}
      echo "$feat_dt" > $expdir/cntk_valid.$noisyinput.${feat}_${fvariety}
    done
  done

  feat-to-len "$feat_tr" ark,t:- > $expdir/cntk_train.counts || exit 1;
  feat-to-len "$feat_dt" ark,t:- > $expdir/cntk_valid.counts || exit 1;

  for feat in `echo "${clean_feat_types}" | tr "_" " "`; do
    if [ $feat == "labels" ]; then
      labels_tr="ark:ali-to-pdf $alidir_tr/final.mdl \"ark:gunzip -c $alidir_tr/ali.*.gz |\" ark:- | ali-to-post ark:- ark:- |"
      labels_dt="ark:ali-to-pdf $alidir_dt/final.mdl \"ark:gunzip -c $alidir_dt/ali.*.gz |\" ark:- | ali-to-post ark:- ark:- |"
      echo "$labels_tr" > $expdir/cntk_train.${clean_type}.${feat}
      echo "$labels_dt" > $expdir/cntk_valid.${clean_type}.${feat}
      continue
    fi 
    for ch in `echo $clean_channels | tr "_" " "`; do
      fvariety=${featurevariety[$feat]}
      cleaninput=${clean_type}${ch}
      # change from simu to multi for cross-entropy tasks
      feat_tr="scp:data/${feat}_${fvariety}/tr05_simu_${cleaninput}/feats.scp"
      feat_dt="scp:data/${feat}_${fvariety}/dt05_simu_${cleaninput}/feats.scp"
      echo "$feat_tr" > $expdir/cntk_train.$cleaninput.${feat}_${fvariety}
      echo "$feat_dt" > $expdir/cntk_valid.$cleaninput.${feat}_${fvariety}
    done
  done
fi # stage -le 4


# stacking features
if [ $stage -le 5 ]; then

if [ ${num_noisy_channels} -gt 1 ]; then
for feat in `echo "${noisy_feat_types}" | tr "_" " "`; do
  fvariety=${featurevariety[$feat]}
  for dataset in dt05_real et05_real tr05_real dt05_simu et05_simu tr05_simu; do
    # noisy feat stacking
    if [ ! -d data/${feat}_${fvariety}/${dataset}_${noisy_type}${noisy_channels} ]; then
      echo -n "./steps/append_feats.sh --cmd "${train_cmd}" --nj ${njspk} " >  $expdir/stacknoisy_${feat}_${dataset}.sh
      for ch in `echo $noisy_channels | tr "_" " "`; do
	noisyinput=${noisy_type}${ch}
	x=${dataset}_${noisyinput}
	echo -n "data/${feat}_${fvariety}/$x " >> $expdir/stacknoisy_${feat}_${dataset}.sh
      done
      echo -n "data/${feat}_${fvariety}/${dataset}_${noisy_type}${noisy_channels} " >> $expdir/stacknoisy_${feat}_${dataset}.sh
      echo -n "$expdir/append_${feat}_${dataset}_${noisy_type}${noisy_channels} " >> $expdir/stacknoisy_${feat}_${dataset}.sh
      echo -n "dataraw/${feat}_${fvariety}" >> $expdir/stacknoisy_${feat}_${dataset}.sh
      bash $expdir/stacknoisy_${feat}_${dataset}.sh
    fi
  done
  feat_tr="scp:data/${feat}_${fvariety}/tr05_simu_${noisy_type}${noisy_channels}/feats.scp"
  feat_dt="scp:data/${feat}_${fvariety}/dt05_simu_${noisy_type}${noisy_channels}/feats.scp"
  echo "$feat_tr" > $expdir/cntk_train.${noisy_type}${noisy_channels}.${feat}_${fvariety}
  echo "$feat_dt" > $expdir/cntk_valid.${noisy_type}${noisy_channels}.${feat}_${fvariety}
done
fi

if [ ${num_clean_channels} -gt 1 ]; then
  for feat in `echo "${clean_feat_types}" | tr "_" " "`; do
    if [ $feat == "labels" ]; then
      continue
    fi
    fvariety=${featurevariety[$feat]}
    for dataset in dt05_real et05_real tr05_real dt05_simu et05_simu tr05_simu; do
      # clean feat stacking
      if [ ! -d data/${feat}_${fvariety}/${dataset}_${clean_type}${clean_channels} ]; then
        echo -n "./steps/append_feats.sh --cmd "${train_cmd}" --nj ${njspk} " >  $expdir/stackclean_${feat}_${dataset}.sh
        for ch in `echo $clean_channels | tr "_" " "`; do
          cleaninput=${clean_type}${ch}
          x=${dataset}_${cleaninput}
	  echo -n "data/${feat}_${fvariety}/$x " >> $expdir/stackclean_${feat}_${dataset}.sh
        done
        echo -n "data/${feat}_${fvariety}/${dataset}_${clean_type}${clean_channels} " >> $expdir/stackclean_${feat}_${dataset}.sh
        echo -n "$expdir/append_stft_${dataset}_${clean_type}${clean_channels} " >> $expdir/stackclean_${feat}_${dataset}.sh
        echo -n "dataraw/${feat}_${fvariety}" >> $expdir/stackclean_${feat}_${dataset}.sh
        bash $expdir/stackclean_${feat}_${dataset}.sh
      fi
    done
    feat_tr="scp:data/${feat}_${fvariety}/tr05_simu_${clean_type}${clean_channels}/feats.scp"
    feat_dt="scp:data/${feat}_${fvariety}/dt05_simu_${clean_type}${clean_channels}/feats.scp"
    echo "$feat_tr" > $expdir/cntk_train.${clean_type}${clean_channels}.${feat}_${fvariety}
    echo "$feat_dt" > $expdir/cntk_valid.${clean_type}${clean_channels}.${feat}_${fvariety}
  done
fi

fi # stage -le 5

####

# stage 6 (TRAIN)
if [ $stage -le 6 ] ; then
echo "Running stage 6: training with CNTK"

ndlfile=$expdir/${model}.ndl
mkdir -p $expdir
## start writing CNTK.config

cat << EOF > ${expdir}/CNTK.config.begin
ExpDir=$expdir

enhHiddenDim=${enhHiddenDim}
enhCellDim=${enhCellDim}
ceHiddenDim=${ceHiddenDim}
ceCellDim=${ceCellDim}

initModel=${expdir}/${initModel}
addLayerMel=${expdir}/${addLayerMel}

enhFeatDim=$enhFeatDim
enhStackFeatDim=$enhStackFeatDim
ceFeatDim=$ceFeatDim
twoCeFeatDim=$twoCeFeatDim
enhMelFileName=$enhMelFileName
ceMelFileName=$ceMelFileName
EnhMelNeedGradient=$EnhMelNeedGradient
CeMelNeedGradient=$CeMelNeedGradient

lrps=${lrps}
trainEpochs=${train_epochs}

action=${action}
frameMode=${frameMode}
truncated=${truncated}
prlUtt=${prlUtt}
minibatchsize=${minibatchsize}
memFrames=${memFrames}
inputCounts=${expdir}/cntk_train.counts
cvInputCounts=${expdir}/cntk_valid.counts
featureTransform=NO_FEATURE_TRANSFORM

command=Train

numCPUThreads=${num_threads}

precision=float

Train=[
    action=$action
    modelPath=$expdir/cntk_model/cntk.nn

    # deviceId=-1 for CPU, >=0 for GPU devices 
    deviceId=${device}
    traceLevel=1
    useValidation=true

    NDLNetworkBuilder=[
        ndlMacros=${expdir}/default_macros.ndl	
        networkDescription=${ndlfile}
    ]

    SGD=[
        epochSize=0         
        minibatchSize=$minibatchsize
        #learningRatesPerMB=0.1:1
	learningRatesPerSample=$lrps
        momentumPerMB=0:0.9
        dropoutRate=0.0
        maxEpochs=${train_epochs}
        numMBsToShowResult=500
    

        #settings for Auto Adjust Learning Rate
        AutoAdjust=[
            reduceLearnRateIfImproveLessThan=0
            loadBestModel=true
            increaseLearnRateIfImproveMoreThan=1000000000
            learnRateDecreaseFactor=0.5
            autoAdjustLR=AdjustAfterEpoch
            learnRateAdjustInterval=1
        ]

        gradientClippingWithTruncation=true
        clippingThresholdPerSample=1#INF
    ]

EOF

cat << EOF > ${expdir}/CNTK.train.reader
    reader=[
      # reader to use
      readerType=Kaldi2Reader
      readMethod=blockRandomize
      frameMode=$frameMode
      Truncated=$truncated
      nbruttsineachrecurrentiter=$prlUtt
      miniBatchMode=Partial
      randomize=$memFrames
      verbosity=0
EOF

cat << EOF > $expdir/CNTK.valid.reader
    cvReader=[
      # reader to use
      readerType=Kaldi2Reader
      readMethod=blockRandomize
      frameMode=$frameMode
      miniBatchMode=Partial
      randomize=$memFrames
      verbosity=0
EOF

for feat in `echo "${noisy_feat_types}" | tr "_" " "`; do
  fvariety=${featurevariety[$feat]}
  feats_tr=`cat $expdir/cntk_train.${noisy_type}${noisy_channels}.${feat}_${fvariety}`
  #feats_dt=`cat $expdir/cntk_valid.${noisy_type}${noisy_channels}.${feat}_${fvariety}`
  baseFeatDim=`feat-to-dim $feats_tr -`
  featDim=`echo "$baseFeatDim * (2 * $frame_context + 1)"|bc`

  #additional arguments for LSTM training, these are required to shift the features
  RowSliceStart=`echo "($frame_context + $frame_shift ) *  $baseFeatDim"|bc`
  cat << EOF >> $expdir/CNTK.config.begin
    noisy${feat}RowSliceStart=$RowSliceStart
    noisy${feat}Dim=${featDim}
EOF
  cat << EOF >> $expdir/CNTK.train.reader
      noisy${feat}=[
    	dim=$featDim
        scpFile=$expdir/cntk_train.counts
	rx=$expdir/cntk_train.${noisy_type}${noisy_channels}.${feat}_${fvariety}
        featureTransform=NO_FEATURE_TRANSFORM
      ]
EOF
  cat << EOF >> $expdir/CNTK.valid.reader
      noisy${feat}=[
    	dim=$featDim
        scpFile=$expdir/cntk_valid.counts
	rx=$expdir/cntk_valid.${noisy_type}${noisy_channels}.${feat}_${fvariety}
        featureTransform=NO_FEATURE_TRANSFORM
      ]
EOF
done

for feat in `echo "${clean_feat_types}" | tr "_" " "`; do
  if [ $feat != "labels" ]; then
  fvariety=${featurevariety[$feat]}
  feats_tr=`cat $expdir/cntk_train.${clean_type}${clean_channels}.${feat}_${fvariety}`
  #feats_dt=`cat $expdir/cntk_valid.${clean_type}${clean_channels}.${feat}_${fvariety}`
  baseFeatDim=`feat-to-dim $feats_tr -`
  featDim=`echo "$baseFeatDim * (2 * $frame_context + 1)"|bc`
  if [ $feat == "stftphase" ]; then
    targetStart=`echo "$baseFeatDim * $num_noisy_channels * $frame_context + $baseFeatDim * ($order_of_target_ch - 1)" | bc -l`
  cat << EOF >> $expdir/CNTK.config.begin
    targetStart=${targetStart}
EOF
  fi
  cat << EOF >> $expdir/CNTK.config.begin
    clean${feat}Dim=${featDim}
EOF
  cat << EOF >> $expdir/CNTK.train.reader
      clean${feat}=[
    	dim=$featDim
        scpFile=$expdir/cntk_train.counts
	rx=$expdir/cntk_train.${clean_type}${clean_channels}.${feat}_${fvariety}
        featureTransform=NO_FEATURE_TRANSFORM
      ]
EOF
  cat << EOF >> $expdir/CNTK.valid.reader
      clean${feat}=[
    	dim=$featDim
        scpFile=$expdir/cntk_valid.counts
	rx=$expdir/cntk_valid.${clean_type}${clean_channels}.${feat}_${fvariety}
        featureTransform=NO_FEATURE_TRANSFORM
      ]
EOF
  elif [ $feat == "labels" ]; then
  labelDim=`am-info $alidir_tr/final.mdl | grep "pdfs" | awk '{print $4;}'`
  for (( c=0; c<labelDim; c++)) ; do
    echo $c
  done >$expdir/cntk_label.mapping
  cat << EOF >> $expdir/CNTK.config.begin
    labelDim=${labelDim}
EOF
  cat << EOF >> $expdir/CNTK.train.reader
      labels=[
        mlfFile=$expdir/cntk_train.${clean_type}.${feat}
        labelDim=$labelDim
        labelMappingFile=$expdir/cntk_label.mapping
      ]
EOF
  cat << EOF >> $expdir/CNTK.valid.reader
      labels=[
        mlfFile=$expdir/cntk_valid.${clean_type}.${feat}
        labelDim=$labelDim
        labelMappingFile=$expdir/cntk_label.mapping
      ]
EOF
  fi
done

echo "    ]" >> $expdir/CNTK.train.reader
echo "    ]" >> $expdir/CNTK.valid.reader

cat $expdir/CNTK.config.begin $expdir/CNTK.train.reader $expdir/CNTK.valid.reader > $expdir/CNTK_main.config

echo "]" >> $expdir/CNTK_main.config

### setup the configuration files for training CNTK models ###
cp cntk_config/default_macros.ndl $expdir/default_macros.ndl
cp cntk_config/${model}.ndl $expdir/${model}.ndl
#cp cntk_config/${addLayerMel} $expdir/${addLayerMel}
#cp cntk_config/${initModel} $expdir/${initModel}

## training command ##

mkdir -p $expdir/log/
parallel_opts=
if [ $num_threads -gt 1 ]; then
  parallel_opts="--num-threads $num_threads"
fi

$cntk_train_cmd $parallel_opts JOB=1:1 $expdir/log/cntk.JOB.log \
  cntk configFile=${expdir}/CNTK_main.config DeviceNumber=$device

fi # if stage -le 6

# stage 7 (enhance dev and test sets)
if [ $stage -le 7 ] ; then

  cp cntk_config/${config_write} $expdir/${config_write}
  cnmodel=$expdir/cntk_model/cntk.dnn.${epoch}
  action=write

  if [ -e $cnmodel ]; then
   echo "Enhancing with trained model from epoch ${epoch}"
 
   #for set in {dt05_simu,et05_simu}; do
   for dataset in {tr05_real,tr05_simu,dt05_real,dt05_simu,et05_real,et05_simu}; do
     datafeat=$noisyfeatdir/${dataset}_${noisy_type}${noisy_channels}
     datastft=$noisystftdir/${dataset}_${noisy_type}5 # we use channel 5
     enh_wav_dir=$expdir/enhance_${noisy_type}_${epoch}
     cntk_string="cntk configFile=${expdir}/${config_write} DeviceNumber=-1 modelName=$cnmodel featDim=$featDim stftDim=$stftDim hstftDim=$hstftDim action=$action ExpDir=$expdir"
     # run in the background and use wait
     local/enhance_cntk_multi.sh --stftconf $stft_config  --nj $njspk --cmd "$decode_cmd" --num-threads ${num_threads} --parallel-opts '-pe smp 4' $wavdir $datafeat $datastft $enh_wav_dir "$cntk_string" &
   done
   wait;
  else
     echo "$cnmodel not found. Try to specify another epoch number with --epoch"
  fi

fi

sleep 3
exit 0

