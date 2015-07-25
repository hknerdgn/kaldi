#!/bin/bash


[ -f ./cmd.sh ] && . ./cmd.sh


nj=4 #10 for AMI, less or equal to 4 for chime3 and reverb
num_threads=3


echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh; # source the path.
. parse_options.sh || exit 1;

if [ $# != 5 ]; then
   echo "Usage: run_fe_fmllr.sh [options] <graph-dir> <gmm-dir> <data-dir> <fmllr-data-dir> <fmllr-wrk-dir>"
   echo "... where <graph-dir> is assumed to be a directory where the graph is located"
   echo "... where <gmm-dir> is assumed to be a directory where the gmm model is located"
   echo "... where <data-dir> is assumed to be a directory where the data wav.scp file is located"
   echo "... where <fmllr-data-dir> is the directory where the fmllr features will be saved"
   echo "... where <fmllr-wrk-dir> is the directory where the fmllr experiment will run"
   echo "e.g.: steps/run_fe_fmllr.sh exp/mono/graph_tgpr data/test_dev93 exp/mono/decode_dev93_tgpr"
   echo ""
   echo ""
   echo "main options (for others, see top of script file)"
   echo "  --nj <nj>                                        # number of parallel jobs"
   echo "  --acwt <float>                                   # acoustic scale used for lattice generation "
   echo "  --num-threads <n>                                # number of threads to use, default 1."
   exit 1;
fi

graph_dir=$1
gmm_dir=$2
data_dir=$3
fmllr_data_dir=$4
fmllr_wrk_dir=$5

echo 
echo

if [ ! -d $graph_dir ]; then
   echo graph dir not found: $graph_dir
   exit 1
fi

if [ ! -d $gmm_dir ]; then
   echo gmm dir not found: $gmm_dir
   exit 1
fi


if [ ! -d $data_dir ]; then
   echo data dir not found: $data_dir
   exit 1
fi


if [ ! -d $fmllr_data_dir ]; then
   echo fmllr data dir not found: $fmllr_data_dir
   exit 1
fi


if [ ! -d $fmllr_wrk_dir ]; then
   echo fmllr wrk dir not found: $fmllr_wrk_dir
   exit 1
fi


# Feature extraction

steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" $data_dir $data_dir/log $data_dir/data
steps/compute_cmvn_stats.sh $data_dir $data_dir/log $data_dir/data

echo feature extraction done


# Create fMLLRed features

steps/decode_fmllr.sh --cmd "$decode_cmd" --nj $nj --num-threads $num_threads \
                      --parallel-opts '-pe smp $num_threads' \
                      --skip-scoring true \
                      $graph_dir $data_dir $fmllr_wrk_dir || exit 1


echo fmllr decoding done

steps/nnet/make_fmllr_feats.sh --nj 1 --cmd "$train_cmd" \
                               --transform-dir $fmllr_wrk_dir \
                               $fmllr_data_dir $data_dir $gmm_dir $fmllr_data_dir/log \
                               $fmllr_data_dir/data || exit 1

echo Making FMLLR features generated
