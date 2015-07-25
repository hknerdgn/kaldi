#!/bin/bash

# Copyright 2013 MERL (author: Felix Weninger)
# Contains some code by Microsoft Corporation, Johns Hopkins University (author: Daniel Povey)
#
# Modified: Marc Delcroix NTT Corporation, July 17 2015
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


# for REVERB challenge:
# original input corpus (original or processed, tr or dt, etc.)
RWSJ_ORIG=$1
if [ ! -d "$RWSJ_ORIG" ]; then
    echo Could not find directory $RWSJ_ORIG! Check pathnames in corpus.sh!
    exit 1
fi

# enhanced input corpus (original or processed, tr or dt, etc.)
RWSJ_ENH=$2
if [ ! -d "$RWSJ_ENH" ]; then
    echo Could not find directory $RWSJ_ENH! Check pathnames in corpus.sh!
    exit 1
fi

# the name of the dataset to be created
dataset=REVERB_Real_dt

if [ ! -z "$3" ]; then
   dataset=$3
fi

# the WSJCAM0 set that the set is based on (tr, dt, ...)
# this will be used to find the correct transcriptions etc.

# dt or et
dt_or_x=dt
if [ ! -z "$4" ]; then
   dt_or_x=$4
fi


mcwsjav_mlf=$RWSJ_ORIG/mlf/WSJ.mlf

enhan=$5


#dir=`pwd`/data/local/data
dir=`pwd`/data/reverb/$enhan/local #/local/data
lmdir=`pwd`/data/local/nist_lm
mkdir -p $dir $lmdir
local=`pwd`/local
utils=`pwd`/utils
#taskFileDir=$dir/../../reverb_tools/ReleasePackage/reverb_tools_for_asr_ver2.0/taskFiles/1ch
taskFileDir=`pwd`/data/local/reverb_tools/ReleasePackage/reverb_tools_for_asr_ver2.0/taskFiles/1ch

root=`pwd`

. ./path.sh # Needed for KALDI_ROOT
export PATH=$PATH:$KALDI_ROOT/tools/irstlm/bin
sph2pipe=$KALDI_ROOT/tools/sph2pipe_v2.5/sph2pipe
if [ ! -x $sph2pipe ]; then
   echo "Could not find (or execute) the sph2pipe program at $sph2pipe";
   exit 1;
fi

cd $dir

MIC=primary


# unfortunately, we need a pointer to HTK baseline 
# since the corpus does NOT contain the data set descriptions 
# for the REVERB Challenge

#taskFiles=`ls $taskFileDir/*Data_dt_for_*`
taskFiles=`ls $taskFileDir/RealData_${dt_or_x}_for_1ch_{far,near}*`

dir2=$dir/${dataset} #${enhan}
mkdir -p $dir2

for taskFile in $taskFiles; do

set=`basename $taskFile`


echo $mcwsjav_mlf

# MLF transcription correction
# taken from HTK baseline script
sed -e '
# dos to unix line feed conversion
s/\x0D$//' \
-e "
            s/\x60//g              # remove unicode character grave accent.
       " \
-e "
            # fix the single quote for the word yield
            # and the quoted ROOTS
            # e.g. yield' --> yield
            # reason: YIELD' is not in dict, while YIELD is
            s/YIELD'/YIELD/g
            s/'ROOTS'/ROOTS/g 
            s/'WHERE/WHERE/g 
            s/PEOPLE'/PEOPLE/g
            s/SIT'/SIT/g
            s/'DOMINEE/DOMINEE/g 
            s/CHURCH'/CHURCH/g" \
-e '
              # fix the single missing double full stop issue at the end of an utterance
              # e.g. I. C. N should be  I. C. N.
              # reason: N is not in dict, while N. is
              /^[A-Z]$/ {
              # append a line
                      N
              # search for single dot on the second line        
                      /\n\./ {
              # found it - now replace the 
                              s/\([A-Z]\)\n\./\1\.\n\./
                      }
              }' \
$mcwsjav_mlf |\
perl $local/mlf2text.pl > $dir2/$set.txt1


# contains pointer to wav files with relative path --> add absolute path
echo taskFile = $taskFile
awk '{print "'$RWSJ_ENH'"$1}' < $taskFile > $dir2/${set}.flist || exit 1;

# this is like flist2scp.pl but it can take wav file list as input
(perl -e 'while(<>){
    m:^\S+/[\w\-]*_(T\w{6,7})\.wav$: || die "Bad line $_";
    $id = lc $1;
    print "$id $_";
}' < $dir2/$set.flist || exit 1) | sort > $dir2/${set}_wav.scp


# Make the utt2spk and spk2utt files.
cat $dir2/${set}_wav.scp | awk '{print $1, $1}' > $dir2/$set.utt2spk || exit 1;
cat $dir2/$set.utt2spk | $utils/utt2spk_to_spk2utt.pl > $dir2/$set.spk2utt || exit 1;

awk '{print $1}' < $dir2/$set.utt2spk |\
$local/find_transcripts_txt.pl $dir2/$set.txt1 | sort | uniq > $dir2/$set.txt
#rm $dir2/$set.txt1

# Create directory structure required by decoding scripts

cd $root
data_dir=data/reverb/$enhan/$set
mkdir -p $data_dir
cp $dir2/${set}_wav.scp ${data_dir}/wav.scp || exit 1;
cp $dir2/$set.txt ${data_dir}/text || exit 1;
cp $dir2/$set.spk2utt ${data_dir}/spk2utt || exit 1;
cp $dir2/$set.utt2spk ${data_dir}/utt2spk || exit 1;

echo "Data preparation for $set succeeded"
#echo "Put files into $dir2/$set.*"


done
