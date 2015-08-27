#!/bin/bash
#
# 
# run_wpe.sh
#
# Perform dereverberation using WPE for long input signals.
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


if [ $# -lt 4 ]; then
  printf "\nUSAGE: %s <scp file> <corpus dir> <result dir> <nb mics> <arrayname file>\n\n" `basename $0`
  echo "... where <scp file> is a path with a file contain wav file list to be processed."
  echo "... <corpus dir> is the path to the original corpus"
  echo "... <result dir> is the path to the dereverberated corpus"
  echo "... <nb mics> is the number of microphones used for dereverberation"
  echo "... <tset> is the target test set (dev/eval)"
  echo "... <array file> is the path to a file giving the mic array naming convention"
  echo "e.g.: local/wpe/run_wpe_wavio.sh data/reverb/wpe8/wav/RealData_dt_for_1ch_near_room1_A.scp"
  echo "      /export/REVERB  data/reverb/wpe8/wav 8 local/wpe/conf/arrayname_reverb_8ch.lst"
  exit 1;
fi


scp=$1
corpusdir=$2
resdir=$3
nbmics=$4
arrayname=$5

matlab=matlab

mkdir -p $resdir

confdir=`pwd`/local/wpe/conf
cfgs=$confdir/conf_wpe_${nbmics}ch_wavio.m
if [ ! -e $cfgs ]; then
    echo $cfgs not found
fi

tooldir=`pwd`/local/wpe


pushd $tooldir

tmpdir=`mktemp -d tempXXXXX `


echo $opts
echo $tmpdir
tmpmfile=$tmpdir/run_mat.m
if [ $nbmics -gt 1 ]; then
    cat <<EOF > $tmpmfile
addpath(genpath('.'))
addpath('$tooldir')
run_wpe_wavio('$cfgs', '$scp', '$corpusdir', '$resdir', '$arrayname');
EOF
else
    cat <<EOF > $tmpmfile
addpath(genpath('.'))
addpath('$tooldir')
run_wpe_wavio('$cfgs', '$scp', '$corpusdir', '$resdir');
EOF
fi
cat $tmpmfile | $matlab -nodisplay
#rm -rf $tmpdir

cat $tmpdir/run_mat.m
popd

echo "Successfully performed dereverberation with WPE and stored it to $resdir." && exit 0;
