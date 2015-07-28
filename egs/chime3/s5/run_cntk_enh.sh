#!/bin/bash

echo do not run this script
echo rather manually run certain sections

exit;

# train and decode cntk rnntify model
local/run_cntk.sh \
 --enhan isolated_beamformed_1sec_scwin_ch1_3-6 \
 --model rnntify_drop_1layer_model \
 --initModel rnntify_drop_1layer_model.ndl \
 --addLayerMel add_rnntify_drop_layer.mel \
 --cntk_config CNTK2_pretrain.config \
 --hiddenDim 1024 \
 --action TrainDNN
exit;

# train and decode cntk dnn model
local/run_cntk.sh \
 --enhan isolated_beamformed_1sec_scwin_ch1_3-6 \
 --model dnn_6layer \
 --cntk_config CNTK2.config \
 --action TrainDNN
exit;

#decode with the trained cntk model only
local/run_cntk.sh \
 --stage 2 \
 --enhan isolated_beamformed_1sec_scwin_ch1_3-6 \
 --model dnn_6layer \
 --cntk_config CNTK2.config \
 --epoch 29
exit;

# train and decode cntk lstm model
local/run_cntk.sh \
 --enhan isolated_beamformed_1sec_scwin_ch1_3-6 \
 --model lstmp-3layer \
 --cntk_config CNTK2_lstm.config \
 --action TrainLSTM
exit;

#decode with the trained cntk model only
local/run_cntk.sh \
 --stage 2 \
 --enhan isolated_beamformed_1sec_scwin_ch1_3-6 \
 --model lstmp-3layer \
 --cntk_config CNTK2_lstm.config \
 --epoch 20
exit;
