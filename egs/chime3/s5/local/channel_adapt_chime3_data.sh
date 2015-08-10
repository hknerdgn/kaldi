#!/bin/bash
set -e

# Modified from the script for CHiME3 baseline
# Shinji Watanabe 02/13/2015
# Hakan Erdogan 08/09/2015

# Begin configuration section.
nj=4
cmd=run.pl
rewrite=true
taps=3200
wavdir=
# End configuration section.

echo "$0 $@"  # Print the command line for logging

if [ -f path.sh ]; then . ./path.sh; fi
. parse_options.sh || exit 1;

set -x

if [ $# != 4 ]; then
   printf "\nUSAGE: %s [options] <dataset> <clean-name> <noisy-name> <reverb-name>\n\n" `basename $0`
   echo "will channel adapt clean-name to noisy-name and the output will be written..."
   echo "to reverb-name which is in the same parent directory as noisy-name directory that contains wav files."
   echo "Example use: $0 --wavdir /path/to/wavdir dt05_real ch0 ch1 reverbch1 "
   echo "options: "
   echo "  --nj <nj>                                        # number of parallel jobs"
   echo "  --rewrite <true|false>                           # rewrite output wavs regardless they exist"
   echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
   echo "  --wavdir <wavdir>                                # where the wavs are"
   exit 1;
fi

echo "$0 $@"  # Print the command line for logging

dataset=$1
cleantype=$2
noisytype=$3
reverbtype=$4

xc=${dataset}_${cleantype}
xn=${dataset}_${noisytype}
xr=${dataset}_${reverbtype}

realsimu=`echo $dataset | sed 's/^.*_//' | sed 's/_.*$//'`

echo "realsimu $realsimu"

for type in ${cleantype} ${noisytype}; do
  x=${dataset}_${type}
  if [ ! -d ${wavdir}/${type} ]; then
    printf "Wave directory ${wavdir}/${type} does not exist. Please provide correct wave directory."
    exit 1;
  fi
  
  if [ ! -d data/$x ] || [ $rewrite == "true" ]; then
        if [ $realsimu == "real" ]; then
          local/real_enhan_chime3_data_prep.sh ${type} ${wavdir}/${type}
        elif [ $realsimu == "simu" ]; then
          local/simu_enhan_chime3_data_prep.sh ${type} ${wavdir}/${type}
        fi
  fi
done

if [ -d data/${xr} ]; then
  if [ $rewrite == true ]; then
    printf "data/${xr} exists, so I will overwrite.\n"
  else 
    printf "data/${xr} exists, so quitting. Provide --rewrite true if need to overwrite.\n"
    exit 1;
  fi
fi

# copy noisy link dir to reverb
utils/copy_data_dir.sh data/${xn} data/${xr}

# edit wav.scp in reverb dir to write into ${wavdir}/${reverbtype} instead of ${wavdir}/${noisytype}
cat data/${xn}/wav.scp | sed "s#${wavdir}/${noisytype}/#${wavdir}/${reverbtype}/#" > data/${xr}/wav.scp
utils/validate_data_dir.sh --no-text --no-feats data/${xr} || exit 1;

# now run channel adapt
for type in $noisytype $cleantype $reverbtype; do
  x=${dataset}_${type}
  mkdir -p data/${x}/split.${nj}
  split_scps=""
  for n in $(seq ${nj}); do
    split_scps="$split_scps data/${x}/split.${nj}/wav.${n}.scp"
  done
  utils/split_scp.pl data/${x}/wav.scp ${split_scps} || exit 1;
done

# make output wav directories
cat data/${xr}/wav.scp | awk '{print $2}' | perl -ple "s#/[^\/]*wav##;" | sort | uniq > data/${xr}/uniqwavdirs.txt
local/mk_mult_dirs.sh data/${xr}/uniqwavdirs.txt

$cmd JOB=1:$nj data/${xr}/split.${nj}/channel_adapt_${reverbtype}.JOB.log \
  channel-adapt --taps=${taps} scp:data/${xc}/split.$nj/wav.JOB.scp scp:data/${xn}/split.$nj/wav.JOB.scp \
    scp:data/${xr}/split.$nj/wav.JOB.scp \
    || exit 1;
