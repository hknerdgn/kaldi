#!/bin/bash


# Copyright Johns Hopkins University (Author: Daniel Povey) 2012
# Copyright University of Edinburgh (Author: Pawel Swietojanski) 2014
# Apache 2.0

if [ $# -le 0 ]; then
    echo "Usage: local/score.sh --task [options]" && exit;
fi

task=$1
echo "$0 $@"  # Print the command line for logging


# pass the arguments for scoring unchanged!
orig_args=
shift 1
while true; do
  [ $# -le 0 ] && break; 
    orig_args="$orig_args $1";
    echo $1
    shift
done

echo $orig_args
echo
echo $task

if [[ $task == "ami" ]]; then
    echo local/score_ami.sh $orig_args
    local/score_ami.sh $orig_args
fi

if [ $task == "chime3" ]; then
    echo local/score_chime3.sh $orig_args
    local/score_chime3.sh $orig_args
fi

if [ $task == "reverb" ]; then
    echo local/score_reverb.sh $orig_args
    local/score_reverb.sh $orig_args
fi