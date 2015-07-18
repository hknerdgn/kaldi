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

# End configuration section
echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh; # source the path.
[ -f ./corpus.sh ] && . ./corpus.sh;

nbmics=8 #1 #2
dataset=REVERB_Real
scp_list=(data/$dataset*/*/wav.scp)
corpusdir=$REVERB_home #/data/work3/marc/REVERB_CHALLENGE/REVERB_DATA_OFFICIAL
resdir=`pwd`/data_wpe$nbmics


echo $coprusdir

arrayname=local/wpe/conf/arrayname_reverb_${nbmics}ch.lst

logdir=$resdir
echo $resdir

#cmd="run.pl"
cmd="queue.pl -l arch=*64* -pe smp 5 --mem 12G -q all.q"

echo -e "Dereverberation with WPE\n"
for scp in ${scp_list[@]}; do
    logname=$(basename $(dirname $scp))
    log=$logdir/$logname.log
    echo $log
    echo $cmd $log local/wpe/run_wpe.sh `pwd`/$scp $corpusdir $resdir $nbmics $arrayname

    #$cmd $log 
    local/wpe/run_wpe.sh `pwd`/$scp $corpusdir $resdir $nbmics $arrayname
done

