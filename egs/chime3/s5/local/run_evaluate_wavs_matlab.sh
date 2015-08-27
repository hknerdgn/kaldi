#!/bin/bash

. ./path.sh
. ./cmd.sh
# header file for the experiment 

stage=0
KALDI_DIR=/data2/erdogan/prog/kaldi
RECIPEDIR=${KALDI_DIR}/egs/chime3/s5
MATLABPATH=$RECIPEDIR/local/matlab
dataset=deveval

rewrite=false

# parallel jobs
nj=20

# original wave files obtained from here
#chime3dir=/local_data2/watanabe/work/201410CHiME3/CHiME3
chime3dir=/data2/erdogan/chime3
ch=5
enhancetype=

echo "$0 $@"  # Print the command line for logging

. parse_options.sh || exit 1;

# all noisy, clean and enhance types are assumed to be located here
# if your enhanced wavs are not located in $wavdir, you should make a link to it
# under the $wavdir with an appropriate name
wavdir=$chime3dir/data/audio/16kHz
cleantype=reverb_ch${ch}
noisytype=ch${ch}
if [ x$enhancetype == "x" ]; then
  enhancetype=ch5_lstmp_3layer_enh_ch${ch}
fi

num_threads=1
parallel_opts=
if [ $num_threads -gt 1 ]; then
  parallel_opts="--num-threads $num_threads"
fi

EXPDIR=${RECIPEDIR}/exp/eval_wavs_only/${enhancetype}
LDIR=$EXPDIR/log
mfiledir=${EXPDIR}/matlab
mkdir -p $mfiledir
evaldir=${EXPDIR}/eval
mkdir -p $evaldir

# check for dir existence

if [ ! -d $wavdir/$cleantype ]; then
  echo "$wavdir/$cleantype for clean wavs does not exist"
  exit
fi
if [ ! -d $wavdir/$noisytype ]; then
  echo "$wavdir/$noisytype for noisy wavs does not exist"
  exit
fi
if [ ! -d $wavdir/$enhancetype ]; then
  echo "$wavdir/$enhancetype for enhanced wavs does not exist"
  exit
fi

# make data dirs for clean and noisy types, and enhanced files if they do not exist

if [ $stage -le 0 ]; then
for input in $noisytype $cleantype $enhancetype; do
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
for input in $cleantype $noisytype $enhancetype; do
  for realsimu in real simu; do
    all_chan=""
    for dset in dt05 et05 tr05; do
      all_chan=`echo $all_chan data/${dset}_${realsimu}_${input}`
    done
    x=all_${realsimu}_${input}
    if [ ! -d data/$x ] || [ $rewrite == "true" ]; then
      utils/combine_data.sh data/${x} ${all_chan}
    fi
  done
  # combine all_real and all_simu
  if [ ! -d data/all_${input} ] || [ $rewrite == "true" ]; then
    utils/combine_data.sh data/all_${input} data/all_real_${input} data/all_simu_${input}
  fi
  if [ ! -d data/deveval_${input} ] || [ $rewrite == "true" ]; then
    utils/combine_data.sh data/deveval_${input} data/dt05_real_${input} data/dt05_simu_${input} data/et05_real_${input} data/et05_simu_${input}
  fi
done

fi # stage 0

if [ $stage -le 1 ]; then

echo "stage 1"

fi # stage 1

# start eval
if [ $stage -le 2 ]; then

# now split each of noisy clean and enhance
for input in $noisytype $cleantype $enhancetype; do
  utils/split_data.sh --per-utt data/${dataset}_${input} ${nj}
done

mfilebase=eval_${dataset}_$$
mfilebase=`echo $mfilebase | tr '-' '_' | tr '+' '_'` # matlab is picky about -'s, +'s etc

for job in $(seq -f "%01.0f" 1 ${nj}); do

cat << EOF > ${mfiledir}/${mfilebase}_${nj}_${job}.m
addpath('$MATLABPATH');
warning('off','all');
outbase='${evaldir}/results_${dataset}.${nj}.${job}';
param.dataset='CH3';
eval_scp='${RECIPEDIR}/data/${dataset}_${enhancetype}/split${nj}/${job}/wav.scp';
noisy_scp='${RECIPEDIR}/data/${dataset}_${noisytype}/split${nj}/${job}/wav.scp';
clean_scp='${RECIPEDIR}/data/${dataset}_${cleantype}/split${nj}/${job}/wav.scp';
eval_enh_scp(eval_scp, noisy_scp, clean_scp, outbase, param)
EOF
done

logfile=$EXPDIR/log/eval_enh.${nj}.JOB.log
echo "Running evals, check logs in $logfile."
$train_cmd $parallel_opts JOB=1:${nj} $logfile \
  matlab -nodisplay -r "cd ${mfiledir}; ${mfilebase}_${nj}_JOB;"

fi # stage 2

# display eval results
if [ $stage -le 3 ]; then

mfilebase=disp_results_${dataset}_$$
mfilebase=`echo $mfilebase | tr '-' '_' | tr '+' '_'` # matlab is picky about -'s, +'s etc

cat << EOF > ${mfiledir}/${mfilebase}.m
addpath('$MATLABPATH');
warning('off','all');
matformat='${evaldir}/results_${dataset}.${nj}.%d.mat';
outcsv='${evaldir}/results_${enhancetype}.csv';
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

logfile=$EXPDIR/log/disp_res_${enhancetype}_${dataset}.log
echo "Running display eval results, check logs in $logfile."
$train_cmd $parallel_opts JOB=1:1 $logfile \
  matlab -nodisplay -r "cd ${mfiledir}; ${mfilebase};"

fi # stage 3
