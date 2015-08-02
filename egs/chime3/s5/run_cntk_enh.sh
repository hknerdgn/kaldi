#!/bin/bash

echo do not run this script
echo rather manually run certain sections

exit;

wavdir=/export/ws15-ffs-data/corpora/chime3/CHiME3/data/audio/16kHz

# train and apply using cntk dnn model

# DNN feature stacking, multi-channel masking, DNN enhanced multi-channel stft stacking
local/run_cntk_enhance_multi_ed.sh --stage 6 --model dnn_6layer_enh_ed --action TrainDNN
exit;

# LSTM feature stacking
local/run_cntk_enhance_multi.sh --stage 5 --model lstmp_3layer_enh --action TrainLSTM --cntk_config CNTK2_lstm_enh.config --lrps 0.0001
exit;

# DNN feature stacking
local/run_cntk_enhance_multi.sh --stage 6 --model dnn_6layer_enh --action TrainDNN
exit;

local/run_cntk_enhance.sh \
 --noisyinput ch5 \
 --cleaninput reverb_ch5 \
 --model dnn_6layer_reclin_enh \
 --cntk_config CNTK2_enh.config \
 --action TrainDNN
exit;

local/run_cntk_enhance.sh \
 --noisyinput ch5 \
 --cleaninput reverb_ch5 \
 --model dnn_6layer_enh \
 --cntk_config CNTK2_enh.config \
 --action TrainDNN
exit;

local/run_cntk_enhance.sh \
 --noisyinput ch5 \
 --cleaninput reverb_ch5 \
 --model dnn_6layer_enh \
 --cntk_config CNTK2_enh.config \
 --action TrainDNN \ 
 --lrps 0.001 \
 --trsubsetsize 1000 \
 --dtsubsetsize 500
exit;

local/run_cntk_enhance.sh \
 --noisyinput ch5 \
 --cleaninput reverb_ch5 \
 --model lstmp_3layer_enh \
 --cntk_config CNTK2_lstm_enh.config \
 --action TrainLSTM \ 
 --lrps 0.001
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
