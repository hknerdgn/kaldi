#!/bin/bash -u

# Copyright 2009-2012  Microsoft Corporation  Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0.

# Copyright 2015  Mitsubishi Electric Research Laboratories (MERL) (Author: Shinji Watanabe)
# Apache 2.0.

# Copyright 2015  NTT Corporation (Author: Marc Delcroix)
# Apache 2.0.


# Begin configuration section.
reverb_enh_corpus=
enhan=
# End configuration section.

echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh; # source the path.
. parse_options.sh || exit 1;

echo $#

if [ $# != 2 ]; then
   echo "Usage: reverb_data_prep.sh [options] <reverb-corpus> <wsj0-corpus>"
   echo "... where <reverb-corpus> is assumed to be the directory where the"
   echo " original reverb corpus is located."
   echo "... <wsj0-corpus> is assumed to be the directory where the"
   echo " original WSJ0 corpus is located."
   echo "e.g.: local/reverb_data_prep.sh /export/REVERB /export/LDC/LDC93S6A/11-13.1"
   echo ""
   echo ""
   echo "main options (for others, see top of script file)"
   echo "  --reverb-enh-corpus <reverb-enh-corpus>          # directory where the enhanced speech is located."
   echo "  --enhan                                          # keyword describing the enhancement process used"
   exit 1;
fi


reverb_corpus=$1
wsj0_corpus=$2

if [ -z "$reverb_enh_corpus" ]; then
    reverb_enh_corpus=$reverb_corpus
fi

wsjcam0=$reverb_corpus/wsjcam0
reverb_real_dt=$reverb_corpus/MC_WSJ_AV_Dev
reverb_real_et=$reverb_corpus/MC_WSJ_AV_Eval
reverb_real_enh_dt=$reverb_enh_corpus/MC_WSJ_AV_Dev
reverb_real_enh_et=$reverb_enh_corpus/MC_WSJ_AV_Eval


# Prepare wsjcam0 clean data and wsj0 language model.
local/wsjcam0_data_prep.sh $wsjcam0 $wsj0_corpus 

# Prepare merged BEEP/CMU dictionary.
local/wsj_prepare_beep_dict.sh 

# Prepare wordlists, etc.
utils/prepare_lang.sh data/local/dict "<SPOKEN_NOISE>" data/local/lang_tmp data/lang 
	
# Prepare directory structure for clean data. Apply some language model fixes.
local/wsjcam0_format_data.sh 

# Download REVERB tools
dir=`pwd`/data/local/reverb_tools
mkdir -p $dir # $reverb_tr_dir

URL1="http://reverb2014.dereverberation.com/tools/reverb_tools_for_Generate_mcTrainData.tgz"
URL2="http://reverb2014.dereverberation.com/tools/REVERB_TOOLS_FOR_ASR_ver2.0.tgz"
for f in $URL1 $URL2; do
    x=`basename $f`
    if [ ! -e $dir/$x ]; then
	wget $f -O $dir/$x || exit 1;
	tar zxvf $dir/$x -C $dir || exit 1;
    fi
done
URL3="http://reverb2014.dereverberation.com/tools/taskFiles_et.tgz"
x=`basename $URL3`
if [ ! -e $dir/$x ]; then
    wget $URL3 -O $dir/$x || exit 1;
    tar zxvf $dir/$x -C $dir || exit 1;
    cp -fr $dir/`basename $x .tgz`/* $dir/ReleasePackage/reverb_tools_for_asr_ver2.0/taskFiles/
fi

# Download and install nist tools
pushd $dir/ReleasePackage/reverb_tools_for_asr_ver2.0
sed -e "s|^main$|targetSPHEREDir\=tools/SPHERE\ninstall_nist|" installTools > installnist
chmod u+x installnist
./installnist
popd

# Prepare the REVERB "real" dt set from MCWSJAV corpus.
# This creates the data set called REVERB_Real_dt and its subfolders
local/REVERB_mcwsjav_data_prep.sh $reverb_real_dt \
				  $reverb_real_enh_dt \
				  REVERB_Real_dt dt  \
				  $enhan

# The MLF file exists only once in the corpus, namely in the real_dt directory
# so we pass it as 4th argument
local/REVERB_mcwsjav_data_prep.sh $reverb_real_et \
				  $reverb_real_enh_et \
				  REVERB_Real_et et \
				  $enhan

exit 0
