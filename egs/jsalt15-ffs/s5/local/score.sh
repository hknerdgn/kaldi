#!/bin/bash


# Copyright Johns Hopkins University (Author: Daniel Povey) 2012
# Copyright University of Edinburgh (Author: Pawel Swietojanski) 2014
# Apache 2.0

if [ $# -le 0 ]; then
    echo "Usage: local/score.sh <task> [options]" && exit;
fi

task=$1

# pass the arguments for scoring unchanged!
orig_args=
for ((argpos=2; argpos<$#; argpos++)); do
    x=$((arpos))
    orig_args="$orig_args '$x'";
done


task=$1
if [ $task == ami ]; then
    score_ami.sh $orig_args
fi

if [ $task == chime3 ]; then
    score_chime3.sh $orig_args
fi

if [ $task == reverb ]; then
    score_reverb.sh $orig_args
fi