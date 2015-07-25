#!/bin/bash

# Copyright 2015, NTT Corporation (Author: Marc Delcroix)
#
# Apache 2.0


[ -f ./cmd.sh ] && . ./cmd.sh


nj=10 
num_threads=3


echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh; # source the path.
. parse_options.sh || exit 1;

if [ $# != 5 ]; then
   echo "Usage: ami_decode.sh [options]  <dnn-dir> <graph-dir> <data-dir> <decode-dir> <acwt>"
   echo "... where <dnn-dir> is assumed to be a directory where the dnn model is located"
   echo "... where <graph-dir> is assumed to be a directory where the graph is located"
   echo "... where <data-dir> is the directory where the features are located."
   echo "... where <decode-dir> is the directory where the decoding takes place"
   echo "... where <acwt> is the acoustic scale used for lattice generation "
   echo ""
   echo ""
   echo "main options (for others, see top of script file)"
   echo "  --nj <nj>                                        # number of parallel jobs"
   echo "  --num-threads <n>                                # number of threads to use, default 1."
   exit 1;
fi

dnn_dir=$1
graph_dir=$2
data_dir=$3
decode_dir=$4
acwt=$5


# DNN Decoding
steps/nnet/decode.sh --nj $nj --cmd "$decode_cmd" --config conf/decode_dnn.conf \
    --num-threads $num_threads \
    --nnet $dnn_dir/final.nnet --acwt $acwt \
    --srcdir $dnn_dir \
    --skip-scoring true \
    $graph_dir $data_dir $decode_dir

# Scoring
scoring_opts="--min-lmwt 4 --max-lmwt 15"

echo local/score_ami.sh $scoring_opts --cmd "$decode_cmd" $data_dir $graph_dir $decode_dir
local/score_asclite.sh --asclite true $scoring_opts --cmd "$decode_cmd" $data_dir $graph_dir $decode_dir
