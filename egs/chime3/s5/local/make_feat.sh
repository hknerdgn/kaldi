#!/bin/bash

# Copyright 2012  Karel Vesely  Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0
# To be run from .. (one directory up from here)
# see ../run.sh for example

# Begin configuration section.
nj=4
cmd=run.pl
compress=true
rewrite=true
# End configuration section.

echo "$0 $@"  # Print the command line for logging

if [ -f path.sh ]; then . ./path.sh; fi
. parse_options.sh || exit 1;

if [ $# != 6 ]; then
   echo "usage: make_feat.sh [options] <dataset> <inputdir> <ftype> <fvariety> <fconf> <realsimu>";
   echo "options: "
   echo "  --nj <nj>                                        # number of parallel jobs"
   echo "  --rewrite <true|false>                           # rewrite features regardless they exist"
   echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
   exit 1;
fi

  dset=$1 # dt05_real, tr05_real etc.
  input=$2 # channel or enhan or any variety of wav files
  ftype=$3 # fbank or stft
  fvariety=$4 # feature variety
  fconf=$5 # feature config file
  realsimu=$6 # real or simu

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
