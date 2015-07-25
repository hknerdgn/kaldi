#!/bin/bash
set -e

# Copyright 2009-2012  Microsoft Corporation  Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0.

# This is modified from the script in standard Kaldi recipe to account
# for the way the WSJ data is structured on the Edinburgh systems. 
# - Arnab Ghoshal, 29/05/12

# Modified from the script for CHiME3 baseline
# Shinji Watanabe 02/13/2015

# Begin configuration section.
channel=
# End configuration section.


echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh; # source the path.
. parse_options.sh || exit 1;

if [ $# != 3 ]; then
  printf "\nUSAGE: %s <original corpus-directory> <enhanced corpus-directory> <processing tag>\n\n" `basename $0`
  echo "The argument should be a the top-level CHiME3 directory."
  echo "It is assumed that there will be a 'data' subdirectory"
  echo "within the top-level corpus directory."
  echo " --channel                          # reference channel used when multi-channel enhancement output exist"
  exit 1;
fi

orig_corpus_dir=$1
enh_corpus_dir=$2
processing=$3


eval_flag=true # make it true when the evaluation data are released

audio_dir=$enh_corpus_dir 
trans_dir=$orig_corpus_dir/data/transcriptions

echo $audio_dir
echo $trans_dir


echo "extract 5th channel (CH5.wav, the center bottom edge in the front of the tablet) for noisy data"

#dir=`pwd`/data/local/data

dir=`pwd`/data/chime3/$processing/local #/data
lmdir=`pwd`/data/local/nist_lm
mkdir -p $dir $lmdir
local=`pwd`/local
utils=`pwd`/utils

. ./path.sh # Needed for KALDI_ROOT
export PATH=$PATH:$KALDI_ROOT/tools/irstlm/bin
sph2pipe=$KALDI_ROOT/tools/sph2pipe_v2.5/sph2pipe
if [ ! -x $sph2pipe ]; then
  echo "Could not find (or execute) the sph2pipe program at $sph2pipe";
  exit 1;
fi

if $eval_flag; then
list_set="tr05_real_${processing} dt05_real_${processing} et05_real_${processing}"
else
list_set="tr05_real_${processing} dt05_real_${processing}"
fi

cd $dir

find $audio_dir -name *${channel}.wav | grep 'tr05_bus_real\|tr05_caf_real\|tr05_ped_real\|tr05_str_real' | sort -u > tr05_real_${processing}.flist
find $audio_dir -name *${channel}.wav | grep 'dt05_bus_real\|dt05_caf_real\|dt05_ped_real\|dt05_str_real' | sort -u > dt05_real_${processing}.flist
if $eval_flag; then
find $audio_dir -name *${channel}.wav | grep 'et05_bus_real\|et05_caf_real\|et05_ped_real\|et05_str_real' | sort -u > et05_real_${processing}.flist
fi


# make a dot format from json annotation files
cp $trans_dir/tr05_real.dot_all tr05_real.dot
cp $trans_dir/dt05_real.dot_all dt05_real.dot
if $eval_flag; then
cp $trans_dir/et05_real.dot_all et05_real.dot
fi

# make a scp file from file list
for x in $list_set; do
    cat $x.flist | awk -F'[/]' '{print $NF}'| sed -e 's/\.wav/_REAL/' > ${x}_wav.ids
    paste -d" " ${x}_wav.ids $x.flist | sort -k 1 > ${x}_wav.scp
done

#make a transcription from dot
cat tr05_real.dot | sed -e 's/(\(.*\))/\1/' | awk -v channel=${channel} '{print $NF channel"_REAL"}'> tr05_real_${processing}.ids
cat tr05_real.dot | sed -e 's/(.*)//' > tr05_real_${processing}.txt
paste -d" " tr05_real_${processing}.ids tr05_real_${processing}.txt | sort -k 1 > tr05_real_${processing}.trans1
cat dt05_real.dot | sed -e 's/(\(.*\))/\1/' | awk  -v channel=${channel} '{print $NF channel"_REAL"}'> dt05_real_${processing}.ids
cat dt05_real.dot | sed -e 's/(.*)//' > dt05_real_${processing}.txt
paste -d" " dt05_real_${processing}.ids dt05_real_${processing}.txt | sort -k 1 > dt05_real_${processing}.trans1
if $eval_flag; then
cat et05_real.dot | sed -e 's/(\(.*\))/\1/' | awk  -v channel=${channel} '{print $NF channel"_REAL"}'> et05_real_${processing}.ids
cat et05_real.dot | sed -e 's/(.*)//' > et05_real_${processing}.txt
paste -d" " et05_real_${processing}.ids et05_real_${processing}.txt | sort -k 1 > et05_real_${processing}.trans1
fi

# Do some basic normalization steps.  At this point we don't remove OOVs--
# that will be done inside the training scripts, as we'd like to make the
# data-preparation stage independent of the specific lexicon used.
noiseword="<NOISE>";
for x in $list_set;do
  cat $x.trans1 | $local/normalize_transcript.pl $noiseword \
    | sort > $x.txt || exit 1;
done
 
# Make the utt2spk and spk2utt files.
for x in $list_set; do
  cat ${x}_wav.scp | awk -F'_' '{print $1}' > $x.spk
  cat ${x}_wav.scp | awk '{print $1}' > $x.utt
  paste -d" " $x.utt $x.spk > $x.utt2spk
  cat $x.utt2spk | $utils/utt2spk_to_spk2utt.pl > $x.spk2utt || exit 1;
done

# copying data to data/...
for x in $list_set; do
  mkdir -p ../$x
  cp ${x}_wav.scp ../$x/wav.scp || exit 1;
  cp ${x}.txt     ../$x/text    || exit 1;
  cp ${x}.spk2utt ../$x/spk2utt || exit 1;
  cp ${x}.utt2spk ../$x/utt2spk || exit 1;
done

echo "Data preparation succeeded"
