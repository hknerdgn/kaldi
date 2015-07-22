#!/bin/bash

# reverb_bf.sh
#
# Perform beamforming with bemafromit for Reverb data
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
bmf="1 2 3 4 5 6 7 8"
bmf="A B C D E F G H"
nj=1 #30
nbmics=8
resdir=.
beamformit_dir=local/beamformit/beamformit
# End configuration section.

echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh; # source the path.
. parse_options.sh || exit 1;


if [ $# != 4 ]; then
   echo "Usage: reverb_bf.sh [options] <corpus-dir> <enh> <tset> <dataset>"
   echo "... where <corpus-dir> is assumed to be the directory where the"
   echo " original reverb corpus is located."
   echo "... <enh> is a keyword describing the output enhancement"
   echo "... <tset> is the target test set (dt05/et05)"
   echo "... <dataset> is the date set (RealData/SimData)"
   echo "e.g.: local/beaformit/reverb_bf.sh /export/Reverb bf5 dt RealData"
   echo ""
   echo ""
   echo "main options (for others, see top of script file)"
   echo "  --resdir <enahnced data dir>          # directory where to save the the enhanced speech"
   echo "  --nj <nj>                                # number of parallel jobs"
   echo "  --nbmics <number of microphones       # sets the number of microphones used for beamforming (default 5)"
   exit 1;
fi

idir=$1
enh=$2
tset=$3
dataset=$4
[ -f ./cmd.sh ] && . ./cmd.sh;

cmd=$bf_cmd
echo $cmd

odir=$resdir/data_${enh}/reverb

wdir=data_${enh}/reverb/local/$tset
conf=local/beamformit/conf/beamformit.cfg

mkdir -p $odir
mkdir -p $wdir/log

wavfiles=$wdir/wavfiles.list

#make the channel file and wav list file
rm -f $wdir/channels_$nbmics
rm -f $wavfiles

echo source dir : $sdir
echo test set : $tset

if [ $dataset == RealData ]; then
    rooms=1
else
    rooms="1 2 3"
fi

taskdir=data/local/reverb_tools/ReleasePackage/reverb_tools_for_asr_ver2.0/taskFiles/${nbmics}ch

for room in $rooms; do 
    for dist in  near far; do
	wavfiles_cond=$wdir/wavfiles_${dataset}_${tset}_${nbmics}ch_${dist}_room${room}.list
	rm -f $wavfiles_cond

	for line in `cat $taskdir/${dataset}_${tset}_for_${nbmics}ch_${dist}_room${room}_A`; do
	    wav=`echo $line | sed -e "s/.wav//"` 
	    echo $wav >> $wavfiles_cond
	    echo $wav >> $wavfiles
	done

	tasks="$wavfiles_cond"
	for mic in `seq 1 $nbmics`; do
	    mic_idx=
	    case $mic in
		1 ) mic_idx=A ;;
		2 ) mic_idx=B ;;
		3 ) mic_idx=C ;;
		4 ) mic_idx=D ;;
		5 ) mic_idx=E ;;
		6 ) mic_idx=F ;;
		7 ) mic_idx=G ;;
		8 ) mic_idx=H ;;
	    esac
	    
	    task=$taskdir/${dataset}_${tset}_for_${nbmics}ch_${dist}_room${room}_$mic_idx	
	    tasks="$tasks $task"
	done
	echo $tasks

	paste -d' ' $tasks >> $wdir/channels_${nbmics}
    done
done

echo  $wdir/channels_${nbmics}
echo  $wavfiles


#do beamforming

echo -e "Beamforming\n"


$cmd JOB=1:$nj $wdir/log/beamform.JOB.log \
  `pwd`/local/beamformit/beamformit.sh $nj JOB $nbmics $wavfiles $idir $odir $wdir $conf $beamformit_dir &

exit
