#!/bin/bash

# Copyright 2015 University of Sheffield (Jon Barker, Ricard Marxer)
#                Inria (Emmanuel Vincent)
#                Mitsubishi Electric Research Labs (Shinji Watanabe)
#  Apache 2.0  (http://www.apache.org/licenses/LICENSE-2.0)

# This script is made from the kaldi recipe of the 2nd CHiME Challenge Track 2
# made by Chao Weng

. ./path.sh
. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.

# This is a shell script, but it's recommended that you run the commands one by
# one by copying and pasting into the shell.

if [ $# -ne 2 ]; then
  printf "\nUSAGE: %s <enhancement method> <enhanced speech directory>\n\n" `basename $0`
  echo "First argument specifies a unique name for different enhancement method"
  echo "Second argument specifies the directory of enhanced wav files"
  exit 1;
fi


# Set bash to 'debug' mode, it will exit on :                                                                                                                                  # -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',                                                                                        
set -e
set -u
set -o pipefail
set -x

nj=30

# enhan data
enhan=$1
enhan_data=$2

# check whether run_init is executed
if [ ! -d data/lang ]; then
  echo "error, execute local/run_init.sh, first"
  exit 1;
fi

# process for enhan data
local/real_enhan_chime3_data_prep.sh $enhan $enhan_data 
local/simu_enhan_chime3_data_prep.sh $enhan $enhan_data 

# Now make MFCC features for clean, close, and noisy data
# mfccdir should be some place with a largish disk where you
# want to store MFCC features.
mfccdir=mfcc/$enhan
for x in dt05_real_$enhan et05_real_$enhan tr05_real_$enhan dt05_simu_$enhan et05_simu_$enhan tr05_simu_$enhan; do 
  steps/make_mfcc.sh --nj 10 --cmd "$train_cmd" \
    data/$x exp/make_mfcc/$x $mfccdir 
  steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir 
done

# make mixed training set from real and simulation enhancement training data
# multi = simu + real
utils/combine_data.sh data/tr05_multi_$enhan data/tr05_simu_$enhan data/tr05_real_$enhan
utils/combine_data.sh data/dt05_multi_$enhan data/dt05_simu_$enhan data/dt05_real_$enhan
utils/combine_data.sh data/et05_multi_$enhan data/et05_simu_$enhan data/et05_real_$enhan

# decode enhan speech using clean AMs
steps/decode_fmllr.sh --cmd "$decode_cmd" --nj 4 --num-threads 4 --parallel-opts '-pe smp 4'\
  exp/tri3b_tr05_orig_clean/graph_tgpr_5k data/dt05_real_$enhan exp/tri3b_tr05_orig_clean/decode_tgpr_5k_dt05_real_$enhan &
steps/decode_fmllr.sh --cmd "$decode_cmd" --nj 4 --num-threads 4 --parallel-opts '-pe smp 4'\
  exp/tri3b_tr05_orig_clean/graph_tgpr_5k data/dt05_simu_$enhan exp/tri3b_tr05_orig_clean/decode_tgpr_5k_dt05_simu_$enhan &
steps/decode_fmllr.sh --cmd "$decode_cmd" --nj 4 --num-threads 4 --parallel-opts '-pe smp 4'\
  exp/tri3b_tr05_orig_clean/graph_tgpr_5k data/et05_real_$enhan exp/tri3b_tr05_orig_clean/decode_tgpr_5k_et05_real_$enhan &
steps/decode_fmllr.sh --cmd "$decode_cmd" --nj 4 --num-threads 4 --parallel-opts '-pe smp 4'\
  exp/tri3b_tr05_orig_clean/graph_tgpr_5k data/et05_simu_$enhan exp/tri3b_tr05_orig_clean/decode_tgpr_5k_et05_simu_$enhan &

# training models using enhan data
steps/train_mono.sh --boost-silence 1.25 --nj $nj --cmd "$train_cmd" \
  data/tr05_multi_$enhan data/lang exp/mono0a_tr05_multi_$enhan 

steps/align_si.sh --boost-silence 1.25 --nj $nj --cmd "$train_cmd" \
  data/tr05_multi_$enhan data/lang exp/mono0a_tr05_multi_$enhan exp/mono0a_ali_tr05_multi_$enhan 

steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" \
  2000 10000 data/tr05_multi_$enhan data/lang exp/mono0a_ali_tr05_multi_$enhan exp/tri1_tr05_multi_$enhan 

steps/align_si.sh --nj $nj --cmd "$train_cmd" \
  data/tr05_multi_$enhan data/lang exp/tri1_tr05_multi_$enhan exp/tri1_ali_tr05_multi_$enhan 

steps/train_lda_mllt.sh --cmd "$train_cmd" \
  --splice-opts "--left-context=3 --right-context=3" \
  2500 15000 data/tr05_multi_$enhan data/lang exp/tri1_ali_tr05_multi_$enhan exp/tri2b_tr05_multi_$enhan 

steps/align_si.sh  --nj $nj --cmd "$train_cmd" \
  --use-graphs true data/tr05_multi_$enhan data/lang exp/tri2b_tr05_multi_$enhan exp/tri2b_ali_tr05_multi_$enhan  

steps/train_sat.sh --cmd "$train_cmd" \
  2500 15000 data/tr05_multi_$enhan data/lang exp/tri2b_ali_tr05_multi_$enhan exp/tri3b_tr05_multi_$enhan 

utils/mkgraph.sh data/lang_test_tgpr_5k exp/tri3b_tr05_multi_$enhan exp/tri3b_tr05_multi_$enhan/graph_tgpr_5k 

# decode enhan speech using enhan AMs
steps/decode_fmllr.sh --cmd "$decode_cmd" --nj 4 --num-threads 4 --parallel-opts '-pe smp 4'\
  exp/tri3b_tr05_multi_$enhan/graph_tgpr_5k data/dt05_real_$enhan exp/tri3b_tr05_multi_$enhan/decode_tgpr_5k_dt05_real_$enhan &
steps/decode_fmllr.sh --cmd "$decode_cmd" --nj 4 --num-threads 4 --parallel-opts '-pe smp 4'\
  exp/tri3b_tr05_multi_$enhan/graph_tgpr_5k data/dt05_simu_$enhan exp/tri3b_tr05_multi_$enhan/decode_tgpr_5k_dt05_simu_$enhan &
steps/decode_fmllr.sh --cmd "$decode_cmd" --nj 4 --num-threads 4 --parallel-opts '-pe smp 4'\
  exp/tri3b_tr05_multi_$enhan/graph_tgpr_5k data/et05_real_$enhan exp/tri3b_tr05_multi_$enhan/decode_tgpr_5k_et05_real_$enhan &
steps/decode_fmllr.sh --cmd "$decode_cmd" --nj 4 --num-threads 4 --parallel-opts '-pe smp 4'\
  exp/tri3b_tr05_multi_$enhan/graph_tgpr_5k data/et05_simu_$enhan exp/tri3b_tr05_multi_$enhan/decode_tgpr_5k_et05_simu_$enhan &
wait;

# decoded results of enhan speech using clean AMs
local/chime3_calc_wers.sh exp/tri3b_tr05_orig_clean $enhan > exp/tri3b_tr05_orig_clean/best_wer_$enhan.result
head -n 15 exp/tri3b_tr05_orig_clean/best_wer_$enhan.result
# decoded results of enhan speech using enhan AMs
local/chime3_calc_wers.sh exp/tri3b_tr05_multi_$enhan $enhan > exp/tri3b_tr05_multi_$enhan/best_wer_$enhan.result
head -n 15 exp/tri3b_tr05_multi_$enhan/best_wer_$enhan.result
