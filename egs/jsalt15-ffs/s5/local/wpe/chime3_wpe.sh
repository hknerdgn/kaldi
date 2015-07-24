#!/bin/bash

# chime3_wpe.sh
#
# Perform dereverberation using WPE for CHiME3 data
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


if [ $# != 3 ]; then
   echo "Usage: ami_wpe.sh [options] <corpus-dir> <nbmics> <tset>"
   echo "... where <corpus-dir> is assumed to be the directory where the"
   echo " original chime3 corpus is located."
   echo "... <nbmics> is the number of microphones used for dereverberation"
   echo "... <tset> is the target test set (dev/eval)"
   echo "e.g.: local/wpe/ami_wpe.sh /export/CHIME3 6 dt05"
   echo ""
   echo ""
   echo "main options (for others, see top of script file)"
   echo "  --resdir <enahnced data dir>          # directory where to save the the enhanced speech"
   exit 1;
fi

corpusdir=$1
nbmics=$2
tset=$3

if [ -z "$resdir" ]; then
    resdir=data_wpe$nbmics
fi
mkdir -p $resdir


arrayname=local/wpe/conf/arrayname_chime3_${nbmics}ch.lst
refmic=CH1

conds="bus_real caf_real ped_real str_real bus_simu caf_simu ped_simu str_simu" 

cmd=$wpe_cmd

logdir=$resdir
echo $resdir


for cond in $conds; do
    echo $cond
    # Create file list
    scp=$resdir/${tset}_${cond}.scp
    rm -f $scp
    echo -e "Dereverberation with WPE\n"
    for file in `find $corpusdir -iname "*${refmic}.wav" | grep ${tset}_${cond} | sort`; do
	echo "${tset}_${cond} $file" >> $scp
    done
    echo $scp
    logname=${tset}_${cond}
    log=$logdir/$logname.log
    echo $log
    echo $cmd $log local/wpe/run_wpe.sh `pwd`/$scp $corpusdir `pwd`/$resdir $nbmics $arrayname
    
    $cmd $log local/wpe/run_wpe.sh `pwd`/$scp $corpusdir `pwd`/$resdir $nbmics $arrayname &
done

wait