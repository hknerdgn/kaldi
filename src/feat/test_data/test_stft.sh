#!/bin/bash

# Copyright 2015 Hakan Erdogan


echo This script runs an STFT followed by an inverse STFT on 3 wav files
echo Resulting wav files can be compared with original ones in matlab

conf=/tmp/stft_$$.conf
inwavscp=/tmp/wavin_$$.scp
outwavscp=/tmp/wavout_$$.scp
wavtgz=wav.tgz

tar xzvf $wavtgz

# run stft with suggested options below
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
--output_type=real_and_imaginary
#--output_type=amplitude_and_phase
--output_layout=block
#--output_layout=interleaved
EOF

cat << EOF > $inwavscp
M04_050C0101_BUS_REAL wav/M04_050C0101_BUS.wav
M04_050C0104_STR_REAL wav/M04_050C0104_STR.wav
M04_050C0107_PED_REAL wav/M04_050C0107_PED.wav
EOF

cat << EOF > $outwavscp
M04_050C0101_BUS_REAL wav/M04_050C0101_BUS_out.wav
M04_050C0104_STR_REAL wav/M04_050C0104_STR_out.wav
M04_050C0107_PED_REAL wav/M04_050C0107_PED_out.wav
EOF

compute-stft-feats --config=$conf scp:$inwavscp ark:- | compute-inverse-stft --wav-durations=ark:"wav-to-duration scp:$inwavscp ark:- |" --config=$conf ark:- scp:$outwavscp

cat << EOF | matlab -nodisplay

file='wav/M04_050C0101_BUS';
[x,fs]=audioread(sprintf('%s.wav',file));
[y,fs]=audioread(sprintf('%s_out.wav',file));
fprintf('Normalized error for %s is %f\n',file, norm(x-y)/norm(y));

file='wav/M04_050C0104_STR';
[x,fs]=audioread(sprintf('%s.wav',file));
[y,fs]=audioread(sprintf('%s_out.wav',file));
fprintf('Normalized error for %s is %f\n',file, norm(x-y)/norm(y));

file='wav/M04_050C0107_PED';
[x,fs]=audioread(sprintf('%s.wav',file));
[y,fs]=audioread(sprintf('%s_out.wav',file));
fprintf('Normalized error for %s is %f\n',file, norm(x-y)/norm(y));
EOF
