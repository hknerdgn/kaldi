#!/bin/bash

# copyright 2015 Hakan Erdogan

echo "------"
echo this script firsts extracts the 100th frame in each utterance and 
echo concatenates this frame with every other frame in the feats.ark file
echo to form a pasted.ark file
echo this is for testing replicate-fixedlength-features program
echo "------"

wavtgz=wav.tgz
conf=/tmp/stft_$$.conf
inwavscp=/tmp/wavin_$$.scp
segments=/tmp/seg_$$.seg
segments2=/tmp/seg2_$$.seg
feats=/tmp/feats_$$.ark
pasted=/tmp/pasted_$$.ark

tar xzvf $wavtgz
# run compute-stft-feats compute-inverse-stft with suggested options below
cat << EOF > $conf
--sample-frequency=16000
--frame-shift=10.0
--frame-length=40.0
--dither=0
--preemphasis-coefficient=0
--remove-dc-offset=false
--window-type=hamming
--round-to-power-of-two=true
--snip-edges=false
EOF

cat << EOF > $inwavscp
M04_050C0101_BUS_REAL wav/M04_050C0101_BUS.wav
M04_050C0104_STR_REAL wav/M04_050C0104_STR.wav
M04_050C0107_PED_REAL wav/M04_050C0107_PED.wav
EOF

# note segment names are same as uttIds
cat << EOF > $segments
M04_050C0101_BUS_REAL M04_050C0101_BUS_REAL 100 101
M04_050C0104_STR_REAL M04_050C0104_STR_REAL 100 101
M04_050C0107_PED_REAL M04_050C0107_PED_REAL 100 101
EOF

cat << EOF > $segments2
M04_050C0101_BUS_REAL M04_050C0101_BUS_REAL 99 102
M04_050C0104_STR_REAL M04_050C0104_STR_REAL 99 102
M04_050C0107_PED_REAL M04_050C0107_PED_REAL 99 102
EOF

compute-stft-feats --config=$conf scp:$inwavscp ark:$feats
extract-rows $segments ark:$feats ark:- | replicate-fixedlength-feats ark:- ark:"feat-to-len ark:$feats ark:-|" ark:- | paste-feats ark:$feats ark:- ark:$pasted
echo "------------"
echo "Displaying 99th through 101th frames of the pasted files"
echo "Only showing features 0-4 and 1026-1030."
echo "Features are 1026 dimensional."
echo "------------"
extract-rows $segments2 ark:$pasted ark:- | select-feats 0-4,1026-1030 ark:- ark,t:-
