#!/bin/bash
#
# 
# run_wpe.sh
#
# Perform dereverberation using WPE.
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


# settings/sample.scp wav_sample res4  
#scp=settings/sample.scp
#corpusdir=wav_sample
#resdir=res3


if [ $# -lt 4 ]; then
  printf "\nUSAGE: %s <scp file> <corpus dir> <result dir> <nb mics> <arrayname file>\n\n" `basename $0`
  echo "e.g.,:"
  echo " `basename $0` sample.scp XXX YYY"
  exit 1;
fi

#arrayname=$confdir/arrayname_${task}_${nbmics}ch.lst

scp=$1
corpusdir=$2
resdir=$3
nbmics=$4
arrayname=$5

matlab=matlab

mkdir -p $resdir

confdir=`pwd`/local/wpe/conf
cfgs=$confdir/conf_wpe_${nbmics}ch.m
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
run_wpe('$cfgs', '$scp', '$corpusdir', '$resdir', '$arrayname');
EOF
else
    cat <<EOF > $tmpmfile
addpath(genpath('.'))
addpath('$tooldir')
run_wpe('$cfgs', '$scp', '$corpusdir', '$resdir');
EOF
fi
cat $tmpmfile | $matlab -nodisplay
#rm -rf $tmpdir

cat $tmpdir/run_mat.m
popd

echo "Successfully performed dereverberation with WPE and stored it to $resdir." && exit 0;
