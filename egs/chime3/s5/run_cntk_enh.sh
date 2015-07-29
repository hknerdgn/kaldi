#!/bin/bash

echo do not run this script
echo rather manually run certain sections

exit;

# train and apply using cntk dnn model
local/run_cntk_enhance.sh \
 --noisyinput ch5 \
 --cleaninput reverb_ch5 \
 --model dnn_6layer_enh \
 --cntk_config CNTK2_enh.config \
 --action TrainDNN
exit;

#apply the trained cntk model only to write down enhanced files
local/run_cntk_enhance.sh \
 --stage 2 \
 --noisyinput isolated_beamformed_1sec_scwin_ch1_3-6 \
 --model dnn_6layer_enh \
 --cntk_config CNTK2_enh.config \
 --epoch 29
exit;

# train and decode cntk lstm model
local/run_cntk_enhance.sh \
 --noisyinput isolated_beamformed_1sec_scwin_ch1_3-6 \
 --model lstmp_3layer_enh \
 --cntk_config CNTK2_lstm_enh.config \
 --action TrainLSTM
exit;

#decode with the trained cntk model only
local/run_cntk_enhance.sh \
 --stage 2 \
 --noisyinput isolated_beamformed_1sec_scwin_ch1_3-6 \
 --model lstmp_3layer_enh \
 --cntk_config CNTK2_lstm_enh.config \
 --epoch 20
exit;
