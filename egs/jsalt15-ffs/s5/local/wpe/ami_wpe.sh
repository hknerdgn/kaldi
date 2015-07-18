#!/bin/bash

# ami_wpe.sh
#
# Perform dereverberation using WPE for AMI data
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

# End configuration section
echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh; # source the path.
[ -f ./corpus.sh ] && . ./corpus.sh;

nbchannel=8 #1

corpusdir=/export/ws15-ffs-data/corpora/ami
resdir=data_wpe$nbchannel
mkdir -p $resdir

arrayname=local/wpe/conf/arrayname_ami_${nbmics}ch.lst

#cmd="run.pl"
cmd="queue.pl -l arch=*64* --mem 12G -pe smp 6 -q all.q"
					    
logdir=$resdir
echo $resdir

refmic=1
for tset in dev eval; do
    meetings=local/split_${tset}.orig
    for meeting in `cat $meetings`; do
	echo $meeting
	# Create file list
	scp=$resdir/${tset}_${meeting}.scp
	printf "$meeting "  > $scp
	find $corpusdir -iname "*${meeting}*.Array1-0$refmic.wav" | sort >> $scp
	
	logname=${tset}_${meeting}
	log=$logdir/$logname.log
	echo $log
	echo $cmd $log local/wpe/run_wpe_wavio.sh `pwd`/$scp $corpusdir `pwd`/$resdir $nbchannel $arrayname
	
	$cmd $log local/wpe/run_wpe_wavio.sh `pwd`/$scp $corpusdir `pwd`/$resdir $nbchannel $arrayname &
    done
done    
wait
