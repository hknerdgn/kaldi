#!/bin/bash

# Copyright 2015 Hakan Erdogan


echo This script runs channel adaptation of some wav files
echo Resulting wav files can be compared with original ones in matlab

conf=/tmp/stft_$$.conf
wav1=/tmp/wavclean_$$.scp
wav2=/tmp/wavnoisy_$$.scp
wav3=/tmp/wavadapt_$$.scp
wavtgz=wav2.tgz

tar xzvf $wavtgz

cat << EOF > $wav1
F05_440C020E_BUS wav/F05_440C020E_BUS.CH0.wav
F06_440C020A_BUS wav/F06_440C020A_BUS.CH0.wav
M05_440C0203a_BUS wav/M05_440C0203_BUS.CH0.wav
M05_440C0203b_BUS wav/M05_440C0203_BUS.CH0.wav
M05_440C0203c_BUS wav/M05_440C0203_BUS.CH0.wav
M05_440C0203d_BUS wav/M05_440C0203_BUS.CH0.wav
M06_440C020N_BUS wav/M06_440C020N_BUS.CH0.wav
EOF

cat << EOF > $wav2
F05_440C020E_BUS wav/F05_440C020E_BUS.CH5.wav
F06_440C020A_BUS wav/F06_440C020A_BUS.CH4.wav
M05_440C0203a_BUS wav/M05_440C0203_BUS.CH5.wav
M05_440C0203b_BUS wav/M05_440C0203_BUS.CH0_filtered.wav
M05_440C0203c_BUS wav/M05_440C0203_BUS.CH0_delayed.wav
M05_440C0203d_BUS wav/M05_440C0203_BUS.CH0_advanced.wav
M06_440C020N_BUS wav/M06_440C020N_BUS.CH5.wav
EOF

cat << EOF > $wav3
F05_440C020E_BUS wav/F05_440C020E_BUS.CH0_ca5.wav
F06_440C020A_BUS wav/F06_440C020A_BUS.CH0_ca4.wav
M05_440C0203a_BUS wav/M05_440C0203_BUS.CH0_ca5.wav
M05_440C0203b_BUS wav/M05_440C0203_BUS.CH0_cafiltered.wav
M05_440C0203c_BUS wav/M05_440C0203_BUS.CH0_cadelayed.wav
M05_440C0203d_BUS wav/M05_440C0203_BUS.CH0_caadvanced.wav
M06_440C020N_BUS wav/M06_440C020N_BUS.CH0_ca5.wav
EOF

channel-adapt --taps=200 scp:$wav1 scp:$wav2 scp:$wav3
