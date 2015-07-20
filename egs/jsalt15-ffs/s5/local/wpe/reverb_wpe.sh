#!/bin/bash

# reverb_wpe.sh
#
# Perform dereverberation using WPE for REVERB data
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
resdir=
# End configuration section.

echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh; # source the path.
[ -f ./cmd.sh ] && . ./cmd.sh;
. parse_options.sh || exit 1;


if [ $# != 4 ]; then
   echo "Usage: reverb_wpe.sh [options] <corpus-dir> <nbmics> <testset> <codition>"
   echo "... where <corpus-dir> is assumed to be the directory where the"
   echo " original REVERB corpus is located."
   echo "... <nbmics> is the number of microphones used for dereverberation"
   echo "... <tset> is the target test set (dev/eval)"
   echo "e.g.: local/wpe/reverb_wpe.sh /export/REVERB 8 dt05 RealData"
   echo ""
   echo ""
   echo "main options (for others, see top of script file)"
   echo "  --resdir <enahnced data dir>          # directory where to save the the enhanced speech"
   exit 1;
fi

corpusdir=$1
nbmics=$2
tset=$3
dataset=$4 #RealData or SimData

if [ -z "$resdir" ]; then
    resdir=data_wpe$nbmics
fi
mkdir -p $resdir


dists="near far"
if [ $dataset == RealData ]; then
    rooms="1"
    
    if [ $tset == dt ]; then
	subcorpus=MC_WSJ_AV_Dev
    fi
    if [ $tset == et ]; then
	subcorpus=MC_WSJ_AV_Eval
    fi
else
    rooms="1 2 3"
    subcorpus=REVERB_WSJCAM0_$tset
fi

arrayname=local/wpe/conf/arrayname_reverb_${nbmics}ch.lst

logdir=$resdir
echo $resdir
taskdir=data/local/reverb_tools/ReleasePackage/reverb_tools_for_asr_ver2.0/taskFiles/1ch

cmd=$wpe_cmd

echo -e "Dereverberation with WPE\n"
for room in $rooms; do
    for dist in $dists; do
	cond=${dataset}_${tset}_for_1ch_${dist}_room${room}_A
	task=$taskdir/$cond
	scp=$resdir/$cond.scp
	rm -f $scp
	for file in `cat $task`; do
	    fname=`basename $file`
	    echo "$fname $corpusdir/$subcorpus/$file" >> $scp
	done
	echo $scp

	logname=$cond
	log=$logdir/$logname.log
	echo $log
	echo local/wpe/run_wpe.sh `pwd`/$scp $corpusdir $resdir $nbmics $arrayname
	
	$cmd $log local/wpe/run_wpe.sh `pwd`/$scp $corpusdir $resdir $nbmics $arrayname &
    done
done

