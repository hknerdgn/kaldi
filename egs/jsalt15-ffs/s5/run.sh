#!/bin/bash -u

# Copyright 2009-2012  Microsoft Corporation  Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0.

# Copyright 2015  Mitsubishi Electric Research Laboratories (MERL) (Author: Shinji Watanabe)
# Apache 2.0.

# Copyright 2015  NTT Corporation (Author: Marc Delcroix)
# Apache 2.0.

. ./cmd.sh
. ./path.sh


do_ami=false #true #false #true/false
do_chime3=false #true #false #true/fasle
do_reverb=true #false #true #false #true/false

stage=1

. utils/parse_options.sh

multi_mics=false #true # true or false (true if multi-microphone output signals)

# Paths to the corpora
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
	bash local/wpe/ami_wpe.sh $AMI_CORPUS 8 dev
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

    pushd local/beamformit
    bash install_beamformit.sh
    popd

    beamformit_dir=/export/ws15-ffs-data/swatanabe/tools/beamformit/bin/BeamformIt-3.51
    if [ $do_ami == true ];then
	AMI_BF_IN_CORPUS=data_wpe8
	echo Performing beamformit for AMI
	bash local/beamformit/ami_beamformit.sh --beamformit-dir --nj 1 $beamformit_dir $AMI_BF_IN_CORPUS $enhan_ami
    fi

    if [ $do_chime3 == true ];then
	CHIME3_BF_IN_CORPUS=data_wpe6
	echo Performing BEAMFORMIT for CHiME3
	bash local/beamformit/chime3_beamformit.sh --beamformit-dir $beamformit_dir --nj 1 $CHIME3_BF_IN_CORPUS \
	     $enhan_chime3 dt05
	bash local/beamformit/chime3_beamformit.sh --beamformit-dir $beamformit_dir --nj 1 $CHIME3_BF_IN_CORPUS \
	     $enhan_chime3 et05
    fi
    
    if [ $do_reverb == true ];then
	REVERB_BF_IN_CORPUS=data_wpe8
	echo Performing BEAMFORMIT for REVERB
	bash local/beamformit/reverb_beamformit.sh --beamformit-dir $beamformit_dir --nj 1 $REVERB_BF_IN_CORPUS/MC_WSJ_AV_Dev \
	     $enhan_reverb dt RealData 
	bash local/beamformit/reverb_beamformit.sh --beamformit-dir $beamformit_dir --nj 1 $REVERB_BF_IN_CORPUS/MC_WSJ_AV_Eval \
	     $enhan_reverb et RealData 
    fi
# XXXX
exit
####
fi

AMI_ENH_CORPUS=`pwd`/data_wpe8_bf/ami
CHIME3_ENH_CORPUS=`pwd`/data_wpe6_bf/data/audio/16kHz/isolated
REVERB_ENH_CORPUS=`pwd`/data_wpe8_bf


# Data preparation for decoding
if [ $stage -le 2 ]; then
    if [ $do_ami == true ]; then
	echo do ami

	mkdir -p data_${enhan_ami}/ami/local/annotations/
	cp ${AMI_EXP_DIR}/data/local/annotations/dev.txt data_${enhan_ami}/ami/local/annotations/
	cp ${AMI_EXP_DIR}/data/local/annotations/eval.txt data_${enhan_ami}/ami/local/annotations/
	
	if [[ $multi_mics == true ]];then
	    micid=1
	    local/ami_mc_enh_scoring_data_prep.sh --mic $micid $AMI_ENH_CORPUS dev $enhan_ami
	    local/ami_mc_enh_scoring_data_prep.sh --mic $micid $AMI_ENH_CORPUS eval $enhan_ami
	else
	    local/ami_mc_enh_scoring_data_prep.sh $AMI_ENH_CORPUS dev $enhan_ami
	    local/ami_mc_enh_scoring_data_prep.sh $AMI_ENH_CORPUS eval $enhan_ami
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

# Feature extraction
gmm_dir=$AMI_EXP_DIR/exp/$mic/tri4a
fmllr_data=data-fmllr-tri4
fmllr_decode_dir=exp/$mic/tri4a

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

	echo feature extraction AMI task
	
	final_lm=`cat $AMI_EXP_DIR/data/local/lm/final_lm`
	lm_suffix=$final_lm.pr1-7
    
	graph_dir=$AMI_EXP_DIR/exp/$mic/tri4a/graph_${lm_suffix}
	
	for tset in dev eval; do

	    dataset=data_$enhan_ami/ami/$tset
	    fmllr_wrk_dir=${fmllr_decode_dir}/decode_${tset}_$enhan_ami
	    fmllr_data_dir=${fmllr_data}/$enhan_ami/${tset}
	    mkdir -p $fmllr_wrk_dir
	    
	    local/run_fe_fmllr.sh --nj 10 --num-threads 3 \
					  $graph_dir \
					  $gmm_dir \
					  $dataset \
					  $fmllr_data_dir \
					  $fmllr_wrk_dir
					  
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
	    fmllr_data_dir=${fmllr_data}/${tset}05_real_${enhan_chime3}
	    

	    # Does feature extraction an FMLLR
	    local/run_fe_fmllr.sh --nj 4 --num-threads 3 \
					  $graph_dir \
					  $gmm_dir \
					  $dataset \
					  $fmllr_data_dir \
					  $fmllr_wrk_dir
	    
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
			     utils/mkgraph.sh data/lang_ami2reverb \
			     $AMI_EXP_DIR/exp/$mic/tri4a $graph_dir
		echo finished preparing data

		fmllr_wrk_dir=${fmllr_decode_dir}/decode_`basename $dataset`_$enhan_reverb
		fmllr_data_dir=${fmllr_data}/`basename $dataset`_$enhan_reverb
		

		# Does feature extraction an FMLLR
		local/run_fe_fmllr.sh --nj 4 --num-threads 3 \
					      $graph_dir \
					      $gmm_dir \
					      $dataset \
					      $fmllr_data_dir \
					      $fmllr_wrk_dir

	    done
	done
    fi
fi

wait

# Decoding

# AMI models
dnn_dir=$AMI_EXP_DIR/exp/$mic/dnn4_pretrain-dbn_dnn
acwt=0.1

dnn_decode=exp/$mic/dnn4_pretrain-dbn_dnn


if [ $stage -le 4 ]; then

    ###############
    ###############
    # AMI task
    if [ $do_ami == true ]; then

	echo decode AMI task
	
	final_lm=`cat $AMI_EXP_DIR/data/local/lm/final_lm`
	lm_suffix=$final_lm.pr1-7
    
	graph_dir=$AMI_EXP_DIR/exp/$mic/tri4a/graph_${lm_suffix}
	
	for tset in dev eval; do

	    decode_dir=${dnn_decode}/decode_${tset}_${lm_suffix}_${enhan_ami}
	    fmllr_data_dir=${fmllr_data}/$enhan_ami/${tset}
	    scoring_opts=ami
    
            # DNN Decoding
	    steps/nnet/decode.sh --nj 10 --cmd "$decode_cmd" --config conf/decode_dnn.conf \
                --num-threads 3 \
                --nnet $dnn_dir/final.nnet --acwt $acwt \
                --srcdir $dnn_dir \
		--scoring-opts $scoring_opts \
                $graph_dir $fmllr_data_dir $decode_dir &
	    
	done

	
    fi
    ###############
    ###############
    # CHiME3 task
    if [ $do_chime3 == true ]; then
	
	echo decode CHiME3 task
	
	lm_suffix=lm_tgpr_5k
	graph_dir=${fmllr_decode_dir}/graph_${lm_suffix}
	
	
	for tset in dt et; do

	    decode_dir=${dnn_decode}/decode_tgpr_5k_${tset}05_real_${enhan_chime3}
	    fmllr_data_dir=${fmllr_data}/${tset}05_real_${enhan_chime3}
	    
	    scoring_opts=chime3
    
            # DNN Decoding
	    steps/nnet/decode.sh --nj 4 --cmd "$decode_cmd" --config conf/decode_dnn.conf \
                --num-threads 3 \
                --nnet $dnn_dir/final.nnet --acwt $acwt \
                --srcdir $dnn_dir \
		--scoring-opts $scoring_opts \
                $graph_dir $fmllr_data_dir $decode_dir &
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


		decode_dir=${dnn_decode}/decode_tg_5k_`basename $dataset`_$enhan_reverb
		fmllr_data_dir=${fmllr_data}/`basename $dataset`_$enhan_reverb

		scoring_opts=reverb
                
                # DNN Decoding
		steps/nnet/decode.sh --nj 4 --cmd "$decode_cmd" --config conf/decode_dnn.conf \
        　　　　　　--num-threads 3 \
                    --nnet $dnn_dir/final.nnet --acwt $acwt \
                    --srcdir $dnn_dir \
		    --scoring-opts $scoring_opts \
                    $graph_dir $fmllr_data_dir $decode_dir &

	    done
	done
    fi
fi    

wait