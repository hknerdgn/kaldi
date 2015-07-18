#!/bin/bash -u

# Copyright 2009-2012  Microsoft Corporation  Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0.

# Copyright 2015  Mitsubishi Electric Research Laboratories (MERL) (Author: Shinji Watanabe)
# Apache 2.0.

# Copyright 2015  NTT Corporation (Author: Marc Delcroix)
# Apache 2.0.

. ./cmd.sh
. ./path.sh


do_ami=false #false #true #false #true/false
do_chime3=false #true/fasle
do_reverb=true #true #false #true #false #true/false

stage=0
. utils/parse_options.sh

# Keyword describing enhancement
#enhan_ami=mdm8
#enhan_chime3=isolated_beamformed_1sec_scwin_ch1_3-6 #noisy
#enhan_reverb=noenh #isolated_beamformed_1sec_scwin_ch1_3-6

multi_mics=false #true # true or false (true if multi-microphone output signals)

# Paths with the enhanced data (change with your data)
#AMI_ENH_CORPUS=/export/ws15-ffs-data/corpora/ami/beamformed/ 
#CHIME3_ENH_CORPUS=/export/ws15-ffs-data/swatanabe/tools/kaldi-trunk/egs/chime3/s5/beamformit/enhanced_wav/isolated_beamformed_1sec_scwin_ch1_3-6/
#REVERB_ENH_CORPUS=/export/ws15-ffs-data/corpora/reverb/REVERB

#AMI_ENH_CORPUS=/export/ws15-ffs-data/mdelcroix/data/ami/data_wpe8
#CHIME3_ENH_CORPUS=/export/ws15-ffs-data/mdelcroix/data/chime3/data_wpe6/data/audio/16kHz/isolated
#REVERB_ENH_CORPUS=/export/ws15-ffs-data/mdelcroix/data/REVERB/data_wpe8



AMI_CORPUS=/export/ws15-ffs-data/corpora/ami
CHIME3_CORPUS=/export/ws15-ffs-data/corpora/chime3/CHiME3
REVERB_CORPUS=/export/ws15-ffs-data/corpora/reverb/REVERB
WSJ0_CORPUS=/export/ws15-ffs-data/corpora/LDC/LDC93S6A/11-13.1


# Sets the AMI model to use
mic=mdm8 #ihm ##sdm1 not trained

#AMI_EXP_DIR=`pwd`/../../ami/s5
AMI_EXP_DIR=/export/ws15-ffs-data/swatanabe/tools/kaldi-trunk/egs/ami/s5

# Dereverberation with WPE
enhan_ami=wpe8
enhan_chime3=wpe6
enhan_reverb=wpe8

AMI_ENH_CORPUS=data_wpe8
CHIME3_ENH_CORPUS=data_wpe6
REVERB_ENH_CORPUS=data_wpe8

if [ $stage -le 0 ]; then

    # install wpe dereverebeartion package
    # Requires to have WPE package for the moment
    # you can request it by e-mail
    # e-mail marc.delcroix@lab.ntt.co.jp

    pushd local/wpe/
    bash install_wpe.sh /export/ws15-ffs-data/mdelcroix/tools/wpe_v1.2.tgz
    popd

    if [ $do_ami == true ];then
	echo Performing WPE for AMI
	bash local/wpe/ami_wpe.sh  $AMI_CORPUS 8 dev
	bash local/wpe/ami_wpe.sh $AMI_CORPUS 8 eval
    fi

    if [ $do_chime3 == true ];then
	echo Performing WPE for CHiME3
	bash local/wpe/chime3_wpe.sh $CHIME3_CORPUS 6 dt05
	bash local/wpe/chime3_wpe.sh $CHIME3_CORPUS 6 et05
    fi
    
    if [ $do_reverb == true ];then
	echo Performing WPE for REVERB
	bash local/wpe/reverb_wpe.sh $REVERB_CORPUS 8 dt RealData
	bash local/wpe/reverb_wpe.sh $REVERB_CORPUS 8 et RealData
    fi
fi
wait


# Beamforming with beaformit 
enhan_ami=wpe8_bf
enhan_chime3=wpe6_bf
enhan_reverb=wpe8_bf
if [ $stage -le 1 ]; then

    pushd local/beanformit
    bash install_beamformit.sh
    popd
    
    if [ $do_ami == true ];then
	AMI_BF_IN_CORPUS=data_wpe8_bf
	echo Performing beamformit for AMI
	bash local/beanformit/ami_beamformit.sh $AMI_BF_IN_CORPUS $enhan_ami
    fi

    if [ $do_chime3 == true ];then
	CHIME3_BF_IN_CORPUS=data_wpe6_bf
	echo Performing BEAMFORMIT for CHiME3
	bash local/beamformit/chime3_beamformit.sh $CHIME3_BF_IN_CORPUS \
	     $enhan_chime3 dt05
	bash local/beamformit/chime3_beamformit.sh $CHIME3_BF_IN_CORPUS \
	     $enhan_chime3 et05
    fi
    
    if [ $do_reverb == true ];then
	REVERB_BF_IN_CORPUS=data_wpe8_bf
	echo Performing BEAMFORMIT for REVERB
	bash local/beamformit/reverb_beamformit.sh $REVERB_BF_IN_CORPUS \
	     $enhan_reverb dt RealData
	bash local/beamformit/reverb_beamformit.sh $REVERB_BF_IN_CORPUS \
	     $enhan_reverb et RealData
    fi
fi

AMI_ENH_CORPUS=data_wpe8_bf
CHIME3_ENH_CORPUS=data_wpe6_bf
REVERB_ENH_CORPUS=data_wpe8_bf


# Data preparation for decoding
if [ $stage -le 2 ]; then
    if [ $do_ami == true ]; then
	echo do ami

	mkdir -p data/local/annotations/
	cp ${AMI_EXP_DIR}/data/local/annotations/dev.txt data/local/annotations/
	cp ${AMI_EXP_DIR}/data/local/annotations/eval.txt data/local/annotations/
	
	if [[ $multi_mics == true ]];then
	    micid=1
	    local/ami_mc_enh_scoring_data_prep.sh $AMI_ENH_CORPUS $micid dev $enhan_ami
	    local/ami_mc_enh_scoring_data_prep.sh $AMI_ENH_CORPUS $micid eval $enhan_ami
	else
	    local/ami_mdm_scoring_data_prep.sh $AMI_ENH_CORPUS $enhan_ami dev
	    local/ami_mdm_scoring_data_prep.sh $AMI_ENH_CORPUS $enhan_ami eval
	fi
    fi
    if [[ $do_chime3 == true ]]; then


	# process for distant talking speech for real and simulation data

	# Does data preparation but not feature extraction
	if [[ $multi_mics == true ]]; then
	    channel=.CH5
	    local/chime3_data_prep.sh --chime3_enh_corpus $CHIME3_ENH_CORPUS \
				  --enhan $enhan_chime3 \
				  --channel $channel \
				  $CHIME3_CORPUS

	else
	    local/chime3_data_prep.sh --chime3_enh_corpus $CHIME3_ENH_CORPUS \
				  --enhan $enhan_chime3 \
				  $CHIME3_CORPUS
	fi
	echo chime3 data preparation

	

	# making HCLG.fst using CHiME3 LM
	# only changes G.fst from CHiME3 LM, and the other (HCL.fst) is from AMI
	./utils/format_lm.sh $AMI_EXP_DIR/data/lang \
			     data/local/nist_lm/lm_tgpr_5k.arpa.gz \
			     $AMI_EXP_DIR/data/local/dict/lexicon.txt \
			     data/lang_ami2chime3
	
    fi
    if [[ $do_reverb == true ]]; then
	echo reverb data preparation
	
	# Does data preparation but not feature extraction
	local/reverb_data_prep.sh --reverb-enh-corpus $REVERB_ENH_CORPUS \
				  --enhan $enhan_reverb \
				   $REVERB_CORPUS $WSJ0_CORPUS

	# making HCLG.fst using REVERB LM
	# only changes G.fst from REVERB LM, and the other (HCL.fst) is from AMI
	./utils/format_lm.sh $AMI_EXP_DIR/data/lang data/local/nist_lm/lm_tg_5k.arpa.gz \
			     $AMI_EXP_DIR/data/local/dict/lexicon.txt data/lang_ami2reverb

    fi
fi

# Decoding

# AMI models
gmm_dir=$AMI_EXP_DIR/exp/$mic/tri4a
dnn_dir=$AMI_EXP_DIR/exp/$mic/dnn4_pretrain-dbn_dnn
acwt=0.1

fmllr_data=data-fmllr-tri4
fmllr_decode_dir=exp/$mic/tri4a
dnn_decode=exp/$mic/dnn4_pretrain-dbn_dnn


if [ $stage -le 3 ]; then

    ###############
    ###############
    # Copy needed files
    if [ ! -f $fmllr_decode_dir/tree ]; then
	echo copying tree
	# Copy exp/$mic/tri4a/tree
	mkdir -p $fmllr_decode_dir
	cp -r $AMI_EXP_DIR/exp/$mic/tri4a/tree     $fmllr_decode_dir/
	cp -r $AMI_EXP_DIR/exp/$mic/tri4a/final*   $fmllr_decode_dir/
	cp -r $AMI_EXP_DIR/exp/$mic/tri4a/*.alimdl $fmllr_decode_dir/
	cp -r $AMI_EXP_DIR/exp/$mic/tri4a/*.mdl    $fmllr_decode_dir/
	cp -r $AMI_EXP_DIR/exp/$mic/tri4a/*.occs   $fmllr_decode_dir/
	cp $AMI_EXP_DIR/exp/$mic/tri4a/splice_opts $fmllr_decode_dir/
    fi
    
    ###############
    ###############
    # AMI task
    if [ $do_ami == true ]; then

	echo decode AMI task
	
	final_lm=`cat $AMI_EXP_DIR/data/local/lm/final_lm`
	lm_suffix=$final_lm.pr1-7
    
	graph_dir=$AMI_EXP_DIR/exp/$mic/tri4a/graph_${lm_suffix}
	
	for tset in dev eval; do

	    tgt=data/$enhan_ami/$tset
	    fmllr_wrk_dir=${fmllr_decode_dir}/decode_${tset}_$enhan_ami
	    decode_dir=${dnn_decode}/decode_${tset}_${lm_suffix}_${enhan_ami}
	    fmllr_data_dir=${fmllr_data}/$enhan_ami/${tset}
	    
	    
	    local/run_dnn_fmllr_decode.sh --nj 10 --num-threads 3 \
					  --graph-dir $graph_dir \
					  --gmm-dir $gmm_dir \
					  --dnn-dir $dnn_dir \
					  --data-dir $tgt \
					  --fmllr-data-dir $fmllr_data_dir \
					  --fmllr-wrk-dir $fmllr_wrk_dir\
					  $decode_dir &
	done

	
    fi
    ###############
    ###############
    # CHiME3 task
    if [ $do_chime3 == true ]; then
	
	echo decode CHiME3 task
	
	lm_suffix=lm_tgpr_5k
	graph_dir=${fmllr_decode_dir}/graph_${lm_suffix}
	
	
	# Making decoding graph
	$highmem_cmd $graph_dir/mkgraph.log \
		     utils/mkgraph.sh data/lang_ami2chime3 \
		     $AMI_EXP_DIR/exp/$mic/tri4a $graph_dir
	
	for tset in dt et; do

	    dataset=data/${tset}05_real_$enhan_chime3
	    fmllr_wrk_dir=${fmllr_decode_dir}/decode_${tset}05_real_$enhan_chime3
	    decode_dir=${dnn_decode}/decode_tgpr_5k_${tset}05_real_${enhan_chime3}
	    fmllr_data_dir=${fmllr_data}/${tset}05_real_${enhan_chime3}
	    
	    # Does feature extraction, FMMLR, and DNN decoding
	    local/run_dnn_fmllr_decode.sh --nj 4 --num-threads 3 \
					  --graph-dir $graph_dir \
					  --gmm-dir $gmm_dir \
					  --dnn-dir $dnn_dir \
					  --data-dir $dataset \
					  --fmllr-data-dir $fmllr_data_dir \
					  --fmllr-wrk-dir $fmllr_wrk_dir\
					  $decode_dir &
	    
	done  
    fi

    ###############
    ###############
    # REVERB task
    if [ $do_reverb == true ]; then
	
	echo decode REVERB task
    
	for tset in dt et; do
	    for dataset in `ls -d data/REVERB_Real_${tset}_${enhan_reverb}/RealData_${tset}*` ; do
		echo $dataset

		lm_suffix=lm_tg_5k
		graph_dir=${fmllr_decode_dir}/graph_${lm_suffix}

		# Making decoding graph
		$highmem_cmd $graph_dir/mkgraph.log \
			     utils/mkgraph.sh data/lang_ami2reverb $AMI_EXP_DIR/exp/$mic/tri4a $graph_dir
		echo finished preparing data

		fmllr_wrk_dir=${fmllr_decode_dir}/decode_`basename $dataset`_$enhan_reverb
		decode_dir=${dnn_decode}/decode_tg_5k_`basename $dataset`_$enhan_reverb
		fmllr_data_dir=${fmllr_data}/`basename $dataset`_$enhan_reverb
		

		# Does feature extraction, FMMLR, and DNN decoding
		local/run_dnn_fmllr_decode.sh --nj 4 --num-threads 3 \
					      --graph-dir $graph_dir \
					      --gmm-dir $gmm_dir \
					      --dnn-dir $dnn_dir \
					      --data-dir $dataset \
					      --fmllr-data-dir $fmllr_data_dir \
					      --fmllr-wrk-dir $fmllr_wrk_dir\
					      $decode_dir &

	    done
	done
    fi
fi    
