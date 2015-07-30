#!/bin/bash

# Copyright 2012-2013 Karel Vesely, Daniel Povey
# 	    2015 Yu Zhang
# 	    2015 Hakan Erdogan
# Apache 2.0

# Begin configuration section.  
nnet= # Optionally pre-select network to use for getting state-likelihoods
feature_transform= # Optionally pre-select feature transform (in front of nnet)
model= # Optionally pre-select transition model
class_frame_counts= # Optionally pre-select class-counts used to compute PDF priors 

stage=0 # stage=1 skips lattice generation
nj=4
cmd=run.pl
use_gpu_id=-1 # disable gpu
#parallel_opts="-pe smp 2" # use 2 CPUs (1 DNN-forward, 1 decoder)
parallel_opts= # use 2 CPUs (1 DNN-forward, 1 decoder)
num_threads=
stftconf=
# End configuration section.

echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh; # source the path.
. parse_options.sh || exit 1;

#wavdir=/local_data2/watanabe/work/201410CHiME3/CHiME3/data/audio/16kHz
wavdir=$1 # main path where the original noisy files are, this will be replaced in the input wav.scp lists with the $dir below
featdir=$2 # where the noisy features are
stftdir=$3 # where the noisy stfts are
dir=$4 # where the output enhanced waves are going to be written
srcdir=`dirname $dir`; # The model directory is one level up from enhanced wav directory.
enhmethod=`basename $dir`; # this is interpreted as the enhmethod
sfdata=$featdir/split$nj;
ssdata=$stftdir/split$nj;

cnstring=$5

mkdir -p $dir/log
[[ -d $sfdata && $featdir/feats.scp -ot $sfdata ]] || split_data.sh $featdir $nj || exit 1;
[[ -d $ssdata && $featdir/feats.scp -ot $ssdata ]] || split_data.sh $stftdir $nj || exit 1;

echo $nj > $dir/num_jobs

# check that files exist
for f in $sfdata/$nj/feats.scp $ssdata/$nj/feats.scp $ssdata/$nj/wav.scp; do
  [ ! -f $f ] && echo "$0: no such file $f" && exit 1;
done

# Create the feature stream:
feats="scp:$sfdata/JOB/feats.scp"
inwav_scp="scp:$ssdata/JOB/wav.scp"
inputCounts="$sfdata/JOB/cntkInput.counts"
inputfeats="$sfdata/JOB/cntkInputFeat.scp"
inputstfts="$ssdata/JOB/cntkInputStft.scp"
# to be made
outwav_scp="scp:$ssdata/JOB/${enhmethod}_wav.scp"

if [ ! -e $sfdata/$nj/cntkInputFeat.scp ] || [ ! -e $ssdata/$nj/${enhmethod}_wav.scp ] || [ ! -e $ssdata/$nj/${enhmethod}_dirs.txt ]; then
$cmd JOB=1:$nj $dir/log/split_input.JOB.log \
   feat-to-len "$feats" ark,t:"$inputCounts" || exit 1;

$cmd JOB=1:$nj $dir/log/make_input.JOB.log \
   echo scp:$sfdata/JOB/feats.scp \> $inputfeats

$cmd JOB=1:$nj $dir/log/make_stft.JOB.log \
   echo scp:$ssdata/JOB/feats.scp \> $inputstfts

$cmd JOB=1:$nj $dir/log/make_outwav.JOB.log \
   cat $ssdata/JOB/wav.scp \| sed "s#$wavdir#$dir#" \> $ssdata/JOB/${enhmethod}_wav.scp

$cmd JOB=1:$nj $dir/log/make_outwavdirlist.JOB.log \
   cat $ssdata/JOB/${enhmethod}_wav.scp \| awk \'{print \$2}\' \| perl -ple \"s#\/[^\/]*wav##\;\" \| sort \| uniq \> $ssdata/JOB/${enhmethod}_dirs.txt

$cmd JOB=1:$nj $dir/log/make_outwavdirs.JOB.log \
   local/mk_mult_dirs.sh $ssdata/JOB/${enhmethod}_dirs.txt
fi


# Run the enhancement in the queue
if [ $stage -le 0 ]; then
  $cmd $parallel_opts JOB=1:$nj $dir/log/decode.JOB.log \
    $cnstring inputCounts=$inputCounts inputFeats=$inputfeats inputStftn=$inputstfts numCPUthreads=${num_threads} \| \
    compute-inverse-stft --config=$stftconf ark:- $outwav_scp || exit 1;
    #compute-inverse-stft --wav-durations=ark:\"wav-to-duration $inwav_scp ark:- \|\" --config=$stftconf ark:- $outwav_scp || exit 1;
fi

exit 0;
