#!/bin/bash

# chime3_bf.sh
#
# Perform beamforming with bemafromit for CHiME3 data
#
# Copyright (c) 2015  Nippon Telegraph and Telephone corporation (NTT). (author: Marc Delcroix)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
# WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
# MERCHANTABLITY OR NON-INFRINGEMENT.
# See the Apache 2 License for the specific language governing permissions and
# limitations under the License.


# Begin configuration section.
wiener_filtering=false
bmf="1 3 4 5 6"
nj=1 #30
nbmics=5
resdir=.
beamformit_dir=local/beamformit/beamformit
# End configuration section.

echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh; # source the path.
. parse_options.sh || exit 1;


if [ $# != 3 ]; then
   echo "Usage: chime3_bf.sh [options] <corpus-dir> <enh> <tset>"
   echo "... where <corpus-dir> is assumed to be the directory where the"
   echo " original chime3 corpus is located."
   echo "... <enh> is a keyword describing the output enhancement"
    echo "... <tset> is the target test set (dt05/et05)"
   echo "e.g.: local/beaformit/chime3_bf.sh /export/CHiME3 bf5 dt05"
   echo ""
   echo ""
   echo "main options (for others, see top of script file)"
   echo "  --resdir <enahnced data dir>          # directory where to save the the enhanced speech"
   echo "  --nj <nj>                                # number of parallel jobs"
   echo "  --nbmics <number of microphones       # sets the number of microphones used for beamforming (default 5)"
   exit 1;
fi

sdir=$1
enh=$2
tset=$3

[ -f ./cmd.sh ] && . ./cmd.sh;

cmd=$bf_cmd
echo $cmd

odir=$resdir/data_${enh}/chime3/data/audio/16kHz/isolated
idir=$sdir/data/audio/16kHz/isolated
#./enhanced_wav/${sdir_name}_beamformed_1sec_scwin_ch1_3-6
wdir=data_${enh}/chime3/local/$tset
conf=local/beamformit/conf/beamformit.cfg

mkdir -p $odir
mkdir -p $wdir/log

wavfiles=$wdir/wavfiles.list

echo "Will use the following channels: $bmf"

#make the channel file and wav list file
rm -f $wdir/channels_$nbmics
rm -f $wavfiles

#for line in `find $idir/ -name "*.CH1.wav" | egrep 'tr05|et05|dt05' | awk -F '/' '{print $(NF-1) "/" $NF}' | sed -e "s/.CH1.wav//" | sort`; do
# does not enhance train data!
echo source dir : $sdir
echo test set : $tset
for line in `find $idir/ -name "*.CH1.wav" | grep $tset | awk -F '/' '{print $(NF-1) "/" $NF}' | sed -e "s/.CH1.wav//" | sort`; do
  channels="${line} "
  echo ${line} >> $wavfiles
  for ch in $bmf; do
    channels="$channels $line.CH$ch.wav"
  done
  echo $channels >> $wdir/channels_$nbmics
done

#do noise cancellation

if [ $wiener_filtering == "true" ]; then
  echo "Wiener filtering not yet implemented."
  exit 1;
fi

#do beamforming

echo -e "Beamforming\n"


$cmd JOB=1:$nj $wdir/log/beamform.JOB.log \
  `pwd`/local/beamformit/beamformit.sh $nj JOB $nbmics $wavfiles $idir $odir $wdir $conf $beamformit_dir &
