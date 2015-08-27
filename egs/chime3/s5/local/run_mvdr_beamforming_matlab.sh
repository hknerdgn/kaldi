#!/bin/bash

. ./path.sh
. ./cmd.sh
# header file for the experiment 

stage=0
bfmethod=mvdr
bfparam=sm_pm #single mask and post mask
KALDI_DIR=/data2/erdogan/prog/kaldi
RECIPEDIR=${KALDI_DIR}/egs/chime3/s5
MATLABPATH=$RECIPEDIR/local/matlab
dataset=deveval

rewrite=false

# parallel jobs
njbf=20
njeval=30

# original wave files obtained from here
#chime3dir=/local_data2/watanabe/work/201410CHiME3/CHiME3
chime3dir=/data2/erdogan/chime3
scenhancevariety=ch5_lstmp_3layer_enh

channels="1 2 3 4 5 6"

echo "$0 $@"  # Print the command line for logging

. parse_options.sh || exit 1;

wavdir=$chime3dir/data/audio/16kHz
scenhancewavdir=${RECIPEDIR}/exp/cntk_enh_${scenhancevariety}/enhance

# provide an enhanced wav dir for mask based MVDR, it should contain all channels
# if not provided, then begin-end mask will be used for spatial covariance estimation


chtext=`echo $channels | sed 's/ //g'`

bfvariety=${chtext}_${bfmethod}_${bfparam}
EXPDIR=$RECIPEDIR/exp/beamforming_${bfvariety}
LDIR=$EXPDIR/log
outputwavdir=${EXPDIR}/beamformed_wavs
mfiledir=${EXPDIR}/matlab
mkdir -p $mfiledir
outscpdir=${EXPDIR}/scp
evaldir=${EXPDIR}/eval
mkdir -p $evaldir

num_threads=1
parallel_opts=
if [ $num_threads -gt 1 ]; then
  parallel_opts="--num-threads $num_threads"
fi

if [ ${bfparam} == sm_pm ]; then
combinemasks=true
combinemethod=max
postmask=true
postmaskmin=0.3
min_lambda=1.0
elif [ ${bfparam} == mm_pm ]; then
combinemasks=false
combinemethod=none
postmask=true
postmaskmin=0.3
min_lambda=1.0
elif [ ${bfparam} == sm_npm ]; then
combinemasks=true
combinemethod=max
postmask=false
postmaskmin=-1
min_lambda=1.0
elif [ ${bfparam} == mm_npm ]; then
combinemasks=false
combinemethod=none
postmask=false
postmaskmin=-1
min_lambda=1.0
elif [ ${bfparam} == sm_pmall ]; then
combinemasks=true
combinemethod=max
postmask=true
postmaskmin=0
min_lambda=1.0
elif [ ${bfparam} == smavg_pm ]; then
combinemasks=true
combinemethod=mean
postmask=true
postmaskmin=0.3
min_lambda=1.0
fi

# make data dirs for noisy channels, (single channel) enhanced files if they do not exist

if [ $stage -le 0 ]; then
for ch in $channels; do
input=ch${ch}
if [ $rewrite == true ]; then
  local/real_enhan_chime3_data_prep.sh ${input} ${wavdir}/${input}
  local/simu_enhan_chime3_data_prep.sh ${input} ${wavdir}/${input}
fi
for dset in dt05 et05 tr05; do
for realsimu in real simu; do
x=${dset}_${realsimu}_${input}
if [ ! -d data/$x ]; then
  if [ $realsimu == "real" ]; then
    local/real_enhan_chime3_data_prep.sh ${input} ${wavdir}/${input}
  elif [ $realsimu == "simu" ]; then
    local/simu_enhan_chime3_data_prep.sh ${input} ${wavdir}/${input}
  fi
fi
done
done
done

# combine data dirs for noisy channels to make the all_real and all_simu and all data sets
# also make deveval data set which includes only dt05_real dt05_simu et05_real et05_simu
for ch in $channels; do
  for realsimu in real simu; do
    all_chan=""
    for dset in dt05 et05 tr05; do
      all_chan=`echo $all_chan data/${dset}_${realsimu}_ch${ch}`
    done
    x=all_${realsimu}_ch${ch}
    if [ ! -d data/$x ] || [ $rewrite == "true" ]; then
      utils/combine_data.sh data/${x} ${all_chan}
    fi
  done
  # combine all_real and all_simu
  if [ ! -d data/all_ch${ch} ] || [ $rewrite == "true" ]; then
    utils/combine_data.sh data/all_ch${ch} data/all_real_ch${ch} data/all_simu_ch${ch}
  fi
  if [ ! -d data/deveval_ch${ch} ] || [ $rewrite == "true" ]; then
    utils/combine_data.sh data/deveval_ch${ch} data/dt05_real_ch${ch} data/dt05_simu_ch${ch} data/et05_real_ch${ch} data/et05_simu_ch${ch}
  fi
done

# now obtain sc enhanced wav data list directories
# we obtain this by replacing the wavdir with scenhancewavdir in the wav list
for ch in $channels; do
  if [ ! -d data/all_${scenhancevariety}_ch${ch} ] || [ $rewrite == "true" ]; then
    utils/copy_data_dir.sh data/all_ch${ch} data/all_${scenhancevariety}_ch${ch}
    cat data/all_ch${ch}/wav.scp | sed "s#${wavdir}#${scenhancewavdir}#" > data/all_${scenhancevariety}_ch${ch}/wav.scp
  fi
  if [ ! -d data/deveval_${scenhancevariety}_ch${ch} ] || [ $rewrite == "true" ]; then
    utils/copy_data_dir.sh data/deveval_ch${ch} data/deveval_${scenhancevariety}_ch${ch}
    cat data/deveval_ch${ch}/wav.scp | sed "s#${wavdir}#${scenhancewavdir}#" > data/deveval_${scenhancevariety}_ch${ch}/wav.scp
  fi
  for dset in all dt05 et05 tr05; do
    for realsimu in real simu; do
      if [ ! -d data/${dset}_${realsimu}_${scenhancevariety}_ch${ch} ] || [ $rewrite == "true" ]; then
        utils/copy_data_dir.sh data/${dset}_${realsimu}_ch${ch} data/${dset}_${realsimu}_${scenhancevariety}_ch${ch}
        cat data/${dset}_${realsimu}_ch${ch}/wav.scp | sed "s#${wavdir}#${scenhancewavdir}#" > data/${dset}_${realsimu}_${scenhancevariety}_ch${ch}/wav.scp
      fi
    done
  done
done

fi # stage 0

if [ $stage -le 1 ]; then
# we run beamforming for ${dataset} which can be all, all_real, all_simu, dt05_real ,tr05_simu etc.
# so we split the dataset for each channel

nj=${njbf}

for ch in $channels; do
  if [ ! -d data/${dataset}_ch${ch}/split${nj}/${nj} ] || [ $rewrite == "true" ]; then
    utils/split_data.sh --per-utt data/${dataset}_ch${ch} ${nj}
  fi
  if [ ! -d data/${dataset}_${scenhancevariety}_ch${ch}/split${nj}/${nj} ] || [ $rewrite == "true" ]; then
    utils/split_data.sh --per-utt data/${dataset}_${scenhancevariety}_ch${ch} ${nj}
  fi
done

mkdir -p ${outscpdir}
mfilebase=mvdr_${dataset}_${scenhancevariety}_$$
mfilebase=`echo $mfilebase | tr '-' '_' | tr '+' '_'` # matlab is picky about -'s, +'s etc

for job in $(seq -f "%01.0f" 1 ${nj}); do

cat << EOF > ${mfiledir}/${mfilebase}_${nj}_${job}.m
addpath('$MATLABPATH');
param.enhancedir='$enhancedir';
param.usemaskvad='false'; % for second round
param.processmask='false'; % for second round
param.tworound='false';
param.noisychannels=[2];
param.method='mvdr';
param.sourcerank=-1;
param.rankmethod='none';
param.combinemasks='${combinemasks}'; % to combine multichannel masks to a single mask
param.combinemethod='${combinemethod}'; % use max to combine, so if even one channel has speech, consider as speech
param.postmask='${postmask}'; % to post apply the mask of the reference mic
param.postmaskmin=${postmaskmin}; % min mask value of the post mask in order not to oversupress!
param.min_lambda=${min_lambda};  % Mike uses 1, so lets try that.
warning('off', 'MATLAB:audiovideo:wavread:functionToBeRemoved');
warning('off','all');
for i=[$channels]
  inwavscps{i}=sprintf('${RECIPEDIR}/data/${dataset}_ch%d/split${nj}/%d/wav.scp',i,${job});
  enhwavscps{i}=sprintf('${RECIPEDIR}/data/${dataset}_${scenhancevariety}_ch%d/split${nj}/%d/wav.scp',i,${job});
end
refwavscp=sprintf('${outscpdir}/ref_wavs_${dataset}_${nj}_%02d.scp',${job}); % the list of reference microphone noisy wavs, output
outputdir='${outputwavdir}';
M=batch_beamform_scp(inwavscps,enhwavscps,outputdir,refwavscp, param);
EOF
done

logfile=$EXPDIR/log/mvdr.${nj}.JOB.log
echo "Running beamforming, check logs in $logfile."
$train_cmd $parallel_opts JOB=1:${nj} $logfile \
  matlab -nodisplay -r "cd ${mfiledir}; ${mfilebase}_${nj}_JOB;"

fi # stage 1

# start eval
if [ $stage -le 2 ]; then

nj=${njeval}

# combine parts of reference mic noisy scps
cat ${outscpdir}/ref_wavs_${dataset}_${nj}_??.scp > ${outscpdir}/ref_wavs_${dataset}.scp

# now make data from the outputs of mvdr beamforming and split it
utils/copy_data_dir.sh data/${dataset}_ch1 data/${dataset}_${bfvariety}
cat data/${dataset}_ch1/wav.scp | sed "s#${wavdir}#${outputwavdir}#" | sed "s#ch1/##" > data/${dataset}_${bfvariety}/wav.scp
utils/split_data.sh --per-utt data/${dataset}_${bfvariety} ${nj}

# now make noisy versions of the mvdr beamformed output (use ref mic of mvdr)
utils/copy_data_dir.sh data/${dataset}_ch1 data/${dataset}_${bfvariety}_noisy
cp ${outscpdir}/ref_wavs_${dataset}.scp data/${dataset}_${bfvariety}_noisy/wav.scp

# now make clean (reverberated) versions of the mvdr beamformed output (use ref mic of mvdr)
utils/copy_data_dir.sh data/${dataset}_${bfvariety}_noisy data/${dataset}_${bfvariety}_reverberated
cat ${outscpdir}/ref_wavs_${dataset}.scp | perl -ple "s#/ch([0-9]+)/#/reverb_ch\1/#;" > data/${dataset}_${bfvariety}_reverberated/wav.scp


mfilebase=eval_${dataset}_${bfvariety}_$$
mfilebase=`echo $mfilebase | tr '-' '_' | tr '+' '_'` # matlab is picky about -'s, +'s etc

for job in $(seq -f "%01.0f" 1 ${nj}); do

cat << EOF > ${mfiledir}/${mfilebase}_${nj}_${job}.m
addpath('$MATLABPATH');
warning('off','all');
outbase='${evaldir}/results_${dataset}.${nj}.${job}';
param.dataset='CH3';
eval_scp='${RECIPEDIR}/data/${dataset}_${bfvariety}/split${nj}/${job}/wav.scp';
noisy_scp='${RECIPEDIR}/data/${dataset}_${bfvariety}_noisy/wav.scp';
clean_scp='${RECIPEDIR}/data/${dataset}_${bfvariety}_reverberated/wav.scp';
eval_enh_scp(eval_scp, noisy_scp, clean_scp, outbase, param)
EOF
done

logfile=$EXPDIR/log/eval_mvdr.${nj}.JOB.log
echo "Running evals, check logs in $logfile."
$train_cmd $parallel_opts JOB=1:${nj} $logfile \
  matlab -nodisplay -r "cd ${mfiledir}; ${mfilebase}_${nj}_JOB;"

fi # stage 2

# display eval results
if [ $stage -le 3 ]; then

nj=${njeval}
mfilebase=disp_results_${dataset}_${bfvariety}_$$

cat << EOF > ${mfiledir}/${mfilebase}.m
addpath('$MATLABPATH');
warning('off','all');
matformat='${evaldir}/results_${dataset}.${nj}.%d.mat';
outcsv='${evaldir}/results_${bfvariety}.csv';
evalscp{1}='${RECIPEDIR}/data/all_ch1/wav.scp';
evalscp{2}='${RECIPEDIR}/data/all_real_ch1/wav.scp';
evalscp{3}='${RECIPEDIR}/data/all_simu_ch1/wav.scp';
evalscp{4}='${RECIPEDIR}/data/tr05_real_ch1/wav.scp';
evalscp{5}='${RECIPEDIR}/data/tr05_simu_ch1/wav.scp';
evalscp{6}='${RECIPEDIR}/data/dt05_real_ch1/wav.scp';
evalscp{7}='${RECIPEDIR}/data/dt05_simu_ch1/wav.scp';
evalscp{8}='${RECIPEDIR}/data/et05_real_ch1/wav.scp';
evalscp{9}='${RECIPEDIR}/data/et05_simu_ch1/wav.scp';
disp_enh_res_scp(matformat,1:${nj},evalscp,outcsv)
EOF

logfile=$EXPDIR/log/disp_res_mvdr_${dataset}.log
echo "Running display eval results, check logs in $logfile."
$train_cmd $parallel_opts JOB=1:1 $logfile \
  matlab -nodisplay -r "cd ${mfiledir}; ${mfilebase};"

fi # stage 3
