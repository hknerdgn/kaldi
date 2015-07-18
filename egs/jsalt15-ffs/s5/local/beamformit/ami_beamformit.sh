#!/bin/bash

# Copyright 2014, University of Edinburgh (Author: Pawel Swietojanski)
#
# Modified 2017/7/18 NTT Corporation (Author: Marc Delcroix)
#
# Apache 2.0

wiener_filtering=false
nj=4
cmd=run.pl
nbmics=8
resdir=.
# End configuration section

echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh; # source the path.
. parse_options.sh || exit 1;

if [ $# != 3 ]; then
   echo "Wrong #arguments ($#, expected 4)"
   echo "Usage: steps/ami_beamform.sh [options] <corpus-dir> <enh>"
   echo "... where <corpus-dir> is assumed to be the directory where the"
   echo " ami corpus is located."
   echo "... <enh> is a keyword describing the output enhancement"
   echo "main options (for others, see top of script file)"
   echo "  --nj <nj>                                # number of parallel jobs"
   echo "  --cmd <cmd>                              # Command to run in parallel with"
   echo "  --wiener-filtering <true/false>          # Cancel noise with Wiener filter prior to beamforming"
   echo "  --nbmics <number of microphones       # sets the number of microphones used for beamforming (default 5)"
   exit 1;
fi

sdir=$1
enh=$2
odir=$resdir/data_$enh
wdir=data/local/$enh


if [ -z "$cmd" ]; then
    cmd=$train_cmd
fi

set -e 
set -u

mkdir -p $odir
mkdir -p $wdir/log

[ -e $odir/.done_$enh ] && echo "Beamforming already done, skipping..." && exit 0

meetings=$wdir/meetings.list

cat local/split_dev.orig local/split_eval.orig | sort > $meetings
# Removing ``lost'' MDM session-ids : http://groups.inf.ed.ac.uk/ami/corpus/dataproblems.shtml 
mv $meetings{,.orig}; grep -v "IS1003b\|IS1007d" $meetings.orig >$meetings

ch_inc=$((8/$nbmics))
bmf=
for ch in `seq 1 $ch_inc 8`; do
  bmf="$bmf $ch"
done

echo "Will use the following channels: $bmf"

# make the channel file,
if [ -f $wdir/channels_$nbmics ]; then
  rm $wdir/channels_$nbmics
fi
touch $wdir/channels_$nbmics

while read line;
do
  channels="$line "
  for ch in $bmf; do
    channels="$channels $line/audio/$line.Array1-0$ch.wav"
  done
  echo $channels >> $wdir/channels_$nbmics
done < $meetings

# do noise cancellation,
if [ $wiener_filtering == "true" ]; then
  echo "Wiener filtering not yet implemented."
  exit 1;
fi

# do beamforming,
echo -e "Beamforming\n"
$cmd JOB=1:$nj $wdir/log/beamform.JOB.log \
     local/beamformit.sh $nj JOB $nbmics $meetings $sdir $odir

touch $odir/.done_$enh
