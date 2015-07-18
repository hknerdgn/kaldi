#!/bin/bash -u

# Copyright 2009-2012  Microsoft Corporation  Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0.

# Copyright 2015  Mitsubishi Electric Research Laboratories (MERL) (Author: Shinji Watanabe)
# Apache 2.0.

# Copyright 2015  NTT Corporation (Author: Marc Delcroix)
# Apache 2.0.

. ./cmd.sh
. ./path.sh

# Begin configuration section.
chime3_enh_corpus=
enhan=noisy
channel= #.CH5
# End configuration section.

echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh; # source the path.
. parse_options.sh || exit 1;


if [ $# != 1 ]; then
   echo "Usage: chime3_data_prep.sh [options] <chime3-corpus>"
   echo "... where <chime3-corpus> is assumed to be the directory where the"
   echo " original reverb corpus is located."
   echo "e.g.: steps/reverb_data_prep.sh /export/REVERB /export/LDC/LDC93S6A/11-13.1"
   echo ""
   echo ""
   echo "main options (for others, see top of script file)"
   echo "  --chime3-enh-corpus <reverb-enh-corpus>          # directory where the enhanced speech is located."
   echo "  --enhan                                          # keyword describing the enhancement process used"
   echo "  --channel                                        # reference channel used when multi-channel enhancement output exist"
   exit 1;
fi


chime3_corpus=$1
if [ -z "$chime3_enh_corpus" ]; then
    chime3_enh_corpus=$chime3_corpus
fi


# CHiME3 data preparation
wsj0_data=$chime3_corpus/data/WSJ0 # directory of WSJ0 in CHiME3. You can also specify your WSJ0 corpus directory

# process for clean speech and making LMs etc. from original WSJ0
# note that training on clean data means original WSJ0 data only (no booth data)
local/clean_wsj0_data_prep.sh $wsj0_data || exit 1;
local/wsj_prepare_dict.sh || exit 1;

utils/prepare_lang.sh data/local/dict "<SPOKEN_NOISE>" data/local/lang_tmp data/lang || exit 1;
local/clean_chime3_format_data.sh || exit 1;

# Create scp files for chime3 task for enhanced speech
if [ ! -z "$channel" ]; then
    local/real_mc_enhan_chime3_data_prep.sh $chime3_corpus \
					    $chime3_enh_corpus\
					    $enhan\
					    --channel $channel || exit 1;
    
    local/simu_mc_enhan_chime3_data_prep.sh $chime3_corpus \
					    $chime3_enh_corpus\
					    $enhan\
					    --channel $channel || exit 1;
else
    local/real_mc_enhan_chime3_data_prep.sh $chime3_corpus \
					    $chime3_enh_corpus\
					    $enhan || exit 1;
    
    local/simu_mc_enhan_chime3_data_prep.sh $chime3_corpus \
					    $chime3_enh_corpus\
					    $enhan || exit 1;

fi
