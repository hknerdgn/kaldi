#!/bin/bash

echo do not run this script
echo rather manually run certain sections

exit;

wavdir=/export/ws15-ffs-data/corpora/chime3/CHiME3/data/audio/16kHz

# train and apply using cntk dnn model

local/run_cntk_ce_multi_ed.sh --stage 5 --action TrainLSTM --cntk_config CNTK2_lstm_ce_ed.config --model lstmp_e3layer_sc_log_d3layer_ce --lrps 0.001 --dtsubsetsize 0 --trsubsetsize 0
exit;

local/run_cntk_ce_multi_ed.sh --stage 7 --action TrainLSTM --config CNTK2_lstm_ce_ed.config --model lstmp_e3layer_sc_log_d3layer_ce.ndl
exit;

# DNN feature stacking, multi-channel masking, DNN enhanced multi-channel stft stacking
local/run_cntk_enhance_multi_ed.sh --stage 4 --model lstmp_e3layer_d3layer_enh --action TrainLSTM --cntk_config CNTK2_lstm_enh_ed.config --lrps 0.0001
exit;

# DNN feature stacking, multi-channel masking, DNN enhanced multi-channel stft stacking
local/run_cntk_enhance_multi_ed.sh --stage 4 --model dnn_6layer_enh_ed --action TrainDNN
exit;

# LSTM feature stacking
local/run_cntk_enhance_multi.sh --stage 4 --model lstmp_3layer_enh --action TrainLSTM --cntk_config CNTK2_lstm_enh.config --lrps 0.0001
exit;

# DNN feature stacking
local/run_cntk_enhance_multi.sh --stage 4 --model dnn_6layer_enh --action TrainDNN
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
local/run_cntk_ce_multi_ed.sh --stage 7 --action TrainLSTM --cntk_config CNTK2_lstm_ce_ed.config --model lstmp_e3layer_sc_log_d3layer_ce --lrps 0.0001 --dtsubsetsize 0 --trsubsetsize 0
local/run_cntk_ce_multi_ed.sh --stage 7 --action TrainLSTM --cntk_config CNTK2_lstm_ce_ed.config --model lstmp_e1layer_sc_logmel_d3layer_ce --lrps 0.0001
local/run_cntk_ce_multi_filter_ed.sh --stage 5 --action TrainLSTM --cntk_config CNTK2_lstm_ce_ed_filter.config --model lstmp_e1layer_filter_sc_logmel_stack_d3layer_ce --lrps 0.0001
local/run_cntk_ce_multi_filter_ed.sh --stage 7 --action TrainLSTM --cntk_config CNTK2_lstm_ce_ed_filter.config --model lstmp_e1layer_avg5filter_sc_logmel_stack_d3layer_ce --device 2 --lrps 0.0001
local/run_cntk_ce_multi_complex_filter_ed.sh --stage 5 --action TrainLSTM --cntk_config CNTK2_lstm_ce_ed_complex_filter.config --model lstmp_e1layer_cmpavg3filter_sc_logmel_stack_d3layer_ce --device 1 --lrps 0.0001
local/run_cntk_ce_multi_complex_filter_ed.sh --stage 5 --device 2 --lrps 0.0008 --trsubsetsize 0 --dtsubsetsize 0 --model lstmp_logmel100_ch5_d3layer_ce
./local/run_cntk_ce_moinv.sh --model gln_2lstmp_untied --device 3 --stage 1
local/run_cntk_ce_mse_complex_filter_ed.sh --stage 5 --device 1 --model lstmp_e1layer_cmpfilter_sc_logmel_stack_d3layer_ce_mse --lrps 0.0005  --cescale 1 --msescale 0.02
local/run_cntk_ce_mse_complex_filter_ed.sh --stage 5 --device 2 --model lstmp_e2layer_cmpfilter_sc_logmel_stack_d3layer_ce_mse --lrps 0.0005  --cescale 1 --msescale 0.004 --trsubsetsize 0 --dtsubsetsize 0
