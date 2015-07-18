#!/bin/bash

[ -f ./cmd.sh ] && . ./cmd.sh


nj=4 #10 for AMI, less or equal to 4 for chime3 and reverb
num_threads=3
acwt=0.1

graph_dir=$AMI_DIR/$graph_dir
gmm_dir=$AMI_DIR/exp/$mic/tri4a
dnn_dir=$AMI_DIR/$dnn_dir

data_dir=data/$enhan_ami/dev
fmllr_data_dir=data-fmllr-tri4/$enhan_ami/dev
fmllr_wrk_dir=exp/$mic/tri4a/decode_dev_$enhan_ami
decode_dir=exp/$mic/dnn4_pretrain-dbn_dnn/decode_dev_${lm_suffix}

echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh; # source the path.
. parse_options.sh || exit 1;

if [ $# != 1 ]; then
   echo "Usage: run_dnn_fmllr_decode.sh [options] <decode-dir>"
   echo "... where <decode-dir> is assumed to be a sub-directory of the directory"
   echo " where the model is."
   echo "e.g.: steps/decode.sh exp/mono/graph_tgpr data/test_dev93 exp/mono/decode_dev93_tgpr"
   echo ""
   echo "This script works on CMN + (delta+delta-delta | LDA+MLLT) features; it works out"
   echo "what type of features you used (assuming it's one of these two)"
   echo ""
   echo "main options (for others, see top of script file)"
   echo "  --nj <nj>                                        # number of parallel jobs"
   echo "  --acwt <float>                                   # acoustic scale used for lattice generation "
   echo "  --num-threads <n>                                # number of threads to use, default 1."
   echo "  --graph-dir <graph-dir>                          #"
   echo "  --gmm-dir <gmm-dir>                              # directory with a trained GMM model"
   echo "  --dnn-dir <dnn-dir>                              # directory with a trained dnn model"
   echo "  --data-dir <data-dir>                            #"
   echo "  --fmllr-data-dir <fmllr-data-dir>                #"
   echo "  --fmllr-wrk-dir <fmllr-wrk-dir>                  #"
   exit 1;
fi

decode_dir=$1


echo 
echo

if [ ! -d $graph_dir ]; then
   echo graph dir not found
   exit 1
fi

if [ ! -d $gmm_dir ]; then
   echo gmm dir not found
   exit 1
fi

if [ ! -d $dnn_dir ]; then
   echo dnn dir not found
   exit 1
fi

# Feature extraction

steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" $data_dir $data_dir/log $data_dir/data
steps/compute_cmvn_stats.sh $data_dir $data_dir/log $data_dir/data


echo 
echo after feature extraction

wait
# Create fMLLRed features

steps/decode_fmllr.sh --cmd "$decode_cmd" --nj $nj --num-threads $num_threads \
                      --parallel-opts '-pe smp $num_threads' \
                      $graph_dir $data_dir $fmllr_wrk_dir &

echo after decode fmllr

wait

steps/nnet/make_fmllr_feats.sh --nj 1 --cmd "$train_cmd" \
                               --transform-dir $fmllr_wrk_dir \
                               $fmllr_data_dir $data_dir $gmm_dir $fmllr_data_dir/log \
                               $fmllr_data_dir/data || exit 1
echo after make fmllr feats
echo

wait

# DNN Decoding
steps/nnet/decode.sh --nj $nj --cmd "$decode_cmd" --config conf/decode_dnn.conf \
                     --num-threads $num_threads \
                     --nnet $dnn_dir/final.nnet --acwt $acwt \
                     --srcdir $dnn_dir \
                     $graph_dir $fmllr_data_dir $decode_dir &
