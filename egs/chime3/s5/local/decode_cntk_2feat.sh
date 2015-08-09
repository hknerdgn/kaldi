#!/bin/bash

# Copyright 2012-2013 Karel Vesely, Daniel Povey
# 	    2015 Yu Zhang
# Apache 2.0

# Begin configuration section.  
nnet= # Optionally pre-select network to use for getting state-likelihoods
feature_transform= # Optionally pre-select feature transform (in front of nnet)
model= # Optionally pre-select transition model
class_frame_counts= # Optionally pre-select class-counts used to compute PDF priors 

stage=0 # stage=1 skips lattice generation
nj=4
cmd=run.pl
max_active=7000 # maximum of active tokens
min_active=200 #minimum of active tokens
max_mem=50000000 # limit the fst-size to 50MB (larger fsts are minimized)
beam=13.0 # GMM:13.0
latbeam=8.0 # GMM:6.0
acwt=0.10 # GMM:0.0833, note: only really affects pruning (scoring is on lattices).
scoring_opts=
skip_scoring=false
use_gpu_id=-1 # disable gpu
#parallel_opts="-pe smp 2" # use 2 CPUs (1 DNN-forward, 1 decoder)
parallel_opts= # use 2 CPUs (1 DNN-forward, 1 decoder)
num_threads=
# End configuration section.

echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh; # source the path.
. parse_options.sh || exit 1;

graphdir=$1
datafeat1=$2
datafeat2=$3
sdatafeat1=$datafeat1/split$nj;
sdatafeat2=$datafeat2/split$nj;
dir=$4
srcdir=`dirname $dir`; # The model directory is one level up from decoding directory.
cnstring=$5

mkdir -p $dir/log
[[ -d $sdatafeat1 && $datafeat1/feats.scp -ot $sdatafeat1 ]] || split_data.sh $datafeat1 $nj || exit 1;
[[ -d $sdatafeat2 && $datafeat2/feats.scp -ot $sdatafeat2 ]] || split_data.sh $datafeat2 $nj || exit 1;
echo $nj > $dir/num_jobs

if [ -z "$model" ]; then # if --model <mdl> was not specified on the command line...
  if [ -z $iter ]; then model=$srcdir/final.mdl; 
  else model=$srcdir/$iter.mdl; fi
fi

for f in $model $graphdir/HCLG.fst; do
  [ ! -f $f ] && echo "decode_cntk_nnet.sh: no such file $f" && exit 1;
done

# check that files exist
for f in $sdatafeat1/1/feats.scp $sdatafeat2/1/feats.scp $model $graphdir/HCLG.fst; do
  [ ! -f $f ] && echo "$0: no such file $f" && exit 1;
done

# PREPARE THE LOG-POSTERIOR COMPUTATION PIPELINE
if [ -z "$class_frame_counts" ]; then
  class_frame_counts=$srcdir/ali_train_pdf.counts
else
  echo "Overriding class_frame_counts by $class_frame_counts"
fi

# Create the feature stream:
feats="scp:$sdatafeat1/JOB/feats.scp"
inputCounts="$sdatafeat1/JOB/cntk_dev.counts"
inputfeats1="$sdatafeat1/JOB/cntkOutput.scp"

if [ ! -f $sdatafeat1/JOB/sls.scp ]; then
    $cmd JOB=1:$nj $dir/log/split_input.JOB.log \
        feat-to-len "$feats" ark,t:"$inputCounts" || exit 1;

    $cmd JOB=1:$nj $dir/log/make_input.JOB.log \
        echo scp:$sdatafeat1/JOB/feats.scp \> $inputfeats1
fi

inputfeats2="$sdatafeat2/JOB/cntkOutput.scp"
if [ ! -f $sdatafeat2/JOB/sls.scp ]; then
    $cmd JOB=1:$nj $dir/log/make_input.JOB.log \
        echo scp:$sdatafeat2/JOB/feats.scp \> $inputfeats2
fi

# Run the decoding in the queue
if [ $stage -le 0 ]; then
  $cmd $parallel_opts JOB=1:$nj $dir/log/decode.JOB.log \
    $cnstring inputCounts=$inputCounts inputFeats1=$inputfeats1 inputFeats2=$inputfeats2 numCPUthreads=${num_threads} \| \
    latgen-faster-mapped --min-active=$min_active --max-active=$max_active --max-mem=$max_mem --beam=$beam --lattice-beam=$latbeam \
    --acoustic-scale=$acwt --allow-partial=true --word-symbol-table=$graphdir/words.txt \
    $model $graphdir/HCLG.fst ark:- "ark:|gzip -c > $dir/lat.JOB.gz" || exit 1;
fi

# Run the scoring
if ! $skip_scoring ; then
  [ ! -x local/score.sh ] && \
    echo "Not scoring because local/score.sh does not exist or not executable." && exit 1;
  local/score.sh $scoring_opts --cmd "$cmd" $datafeat1 $graphdir $dir || exit 1;
fi

exit 0;
