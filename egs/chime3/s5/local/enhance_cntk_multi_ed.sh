#!/bin/bash

# Copyright 2015 Hakan Erdogan
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
allstftdir=$4 # where the all noisy stfts are
dir=$5 # where the output enhanced waves are going to be written
srcdir=`dirname $dir`; # The model directory is one level up from enhanced wav directory.
enhmethod=`basename $srcdir`; # this is interpreted as the enhmethod
sfdata=$featdir/split$nj;
ssdata=$stftdir/split$nj;
sadata=$allstftdir/split$nj;

cnstring=$6

mkdir -p $dir/log
[[ -d $sfdata && $featdir/feats.scp -ot $sfdata ]] || split_data.sh $featdir $nj || exit 1;
[[ -d $ssdata && $featdir/feats.scp -ot $ssdata ]] || split_data.sh $stftdir $nj || exit 1;
[[ -d $sadata && $allfeatdir/feats.stftnmag.scp -ot $sadata ]] || ./local/split_data.sh $allstftdir $nj || exit 1; # special function to deal with stft mag features

echo $nj > $dir/num_jobs

# check that files exist
for f in $sfdata/$nj/feats.scp $ssdata/$nj/feats.scp $ssdata/$nj/wav.scp $sadata/$nj/feats.stftnmag.scp; do
  [ ! -f $f ] && echo "$0: no such file $f" && exit 1;
done

# Create the feature stream:
feats="scp:$sfdata/JOB/feats.scp"
inwav_scp="scp:$ssdata/JOB/wav.scp"
inputCounts="$sfdata/JOB/cntkInput.counts"
inputfeats="$sfdata/JOB/cntkInputFeat.scp"
inputstfts="$ssdata/JOB/cntkInputStft.scp"
inputallstftmags="$ssdata/JOB/cntkAllInputStftMag.scp"
# to be made
outwav_scp="scp:$ssdata/JOB/${enhmethod}_wav.scp"
inwavdur="ark:$ssdata/JOB/wav_durations.ark"

if [ ! -e $sfdata/$nj/cntkInputFeat.scp ] || [ ! -e $ssdata/$nj/cntkInputStft.scp ] || [ ! -e $sfdata/$nj/cntkInput.counts ] || [ ! -e $sfdata/$nj/cntkAllInputStftMag.scp ]; then
$cmd JOB=1:$nj $dir/log/split_input.JOB.log \
   feat-to-len "$feats" ark,t:"$inputCounts" || exit 1;

$cmd JOB=1:$nj $dir/log/make_input.JOB.log \
   echo scp:$sfdata/JOB/feats.scp \> $inputfeats

$cmd JOB=1:$nj $dir/log/make_stft.JOB.log \
   echo scp:$ssdata/JOB/feats.scp \> $inputstfts

$cmd JOB=1:$nj $dir/log/make_allstftmag.JOB.log \
   echo scp:$sadata/JOB/feats.stftnmag.scp \> $inputallstftmags
fi


if [ ! -e $ssdata/$nj/${enhmethod}_wav.scp ] || [ ! -e $ssdata/$nj/${enhmethod}_dirs.txt ]; then
$cmd JOB=1:$nj $dir/log/make_outwav.JOB.log \
   cat $ssdata/JOB/wav.scp \| sed "s#$wavdir#$dir#" \> $ssdata/JOB/${enhmethod}_wav.scp

$cmd JOB=1:$nj $dir/log/make_outwavdirlist.JOB.log \
   cat $ssdata/JOB/${enhmethod}_wav.scp \| awk \'{print \$2}\' \| perl -ple \"s#\/[^\/]*wav##\;\" \| sort \| uniq \> $ssdata/JOB/${enhmethod}_dirs.txt

$cmd JOB=1:$nj $dir/log/make_outwavdirs.JOB.log \
   local/mk_mult_dirs.sh $ssdata/JOB/${enhmethod}_dirs.txt
fi

if [ ! -e $ssdata/$nj/wav_durations.ark ]; then
$cmd JOB=1:$nj $dir/log/make_inwavdur.JOB.log \
   wav-to-duration $inwav_scp $inwavdur
fi


# Run the enhancement in the queue
if [ $stage -le 0 ]; then
  $cmd $parallel_opts JOB=1:$nj $dir/log/enhance.JOB.log \
    $cnstring inputCounts=$inputCounts inputFeats=$inputfeats inputStftn=$inputstfts inputAllStftnMag=$inputallstftmags numCPUthreads=${num_threads} \| \
    compute-inverse-stft --wav-durations=$inwavdur --config=$stftconf ark:- $outwav_scp || exit 1;
fi

exit 0;
