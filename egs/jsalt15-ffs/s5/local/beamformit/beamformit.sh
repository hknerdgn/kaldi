#!/bin/bash

# Copyright 2014, University of Edibnurgh (Author: Pawel Swietojanski)

. ./path.sh

nj=$1
job=$2
numch=$3
wavfiles=$4
sdir=$5
odir=$6
wdir=$7
conf=$8
beamformitdir=$9

echo "$0 $@"  # Print the command line for logging

beamformit=${beamformitdir}/BeamformIt

utils/split_scp.pl -j $nj $((job-1)) $wavfiles $wavfiles.$job

while read line; do

  head=${line%/*}
  mkdir -p $odir/$head
  $beamformit -s $line -c $wdir/channels_$numch \
                        --config_file $conf \
                        --source_dir $sdir \
                        --result_dir $odir

done < $wavfiles.$job

