#!/bin/bash -u

# Copyright 2009-2012  Microsoft Corporation  Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0.

# Copyright 2015  Mitsubishi Electric Research Laboratories (MERL) (Author: Shinji Watanabe)
# Apache 2.0.

# Copyright 2015  NTT Corporation (Author: Marc Delcroix)
# Apache 2.0.

. ./cmd.sh
. ./path.sh


do_ami=true #true/false
do_chime3=false #true/fasle
do_reverb=false #true/false

stage=4

. utils/parse_options.sh

multi_mics=false #true # (true|false) (true if multi-microphone output signals)

# Paths to the corpora
AMI_CORPUS=/export/ws15-ffs-data/corpora/ami
CHIME3_CORPUS=/export/ws15-ffs-data/corpora/chime3/CHiME3
REVERB_CORPUS=/export/ws15-ffs-data/corpora/reverb/REVERB
WSJ0_CORPUS=/export/ws15-ffs-data/corpora/LDC/LDC93S6A/11-13.1


# Sets the AMI model to use
mic=mdm8 #(mdm8|ihm|sdm) # !!! Tested only on mdm8 !!! 

#AMI_EXP_DIR=`pwd`/../../ami/s5
# !! For JSALT Workshop
AMI_EXP_DIR=/export/ws15-ffs-data/swatanabe/tools/kaldi-trunk/egs/ami/s5

# Dereverberation with WPE
enhan_ami=wpe8
enhan_chime3=wpe6
enhan_reverb=wpe8

AMI_ENH_CORPUS=data/ami/$enhan_ami/wav
CHIME3_ENH_CORPUS=data/$enhan_chime3/wpe6/wav
REVERB_ENH_CORPUS=data/$enhan_reverb/wpe8/wav

if [ $stage -le 0 ]; then

    # install wpe dereverebeartion package
    # Requires to have WPE package for the moment
    # you can request it by e-mail
    # e-mail marc.delcroix@lab.ntt.co.jp
    pushd local/wpe/
    install_wpe.sh /export/ws15-ffs-data/mdelcroix/tools/wpe_v1.2.tgz
    popd

    if [ $do_ami == true ];then
	echo Performing WPE for AMI
	local/wpe/ami_wpe.sh --resdir $AMI_ENH_CORPUS $AMI_CORPUS 8 dev
	local/wpe/ami_wpe.sh --resdir $AMI_ENH_CORPUS $AMI_CORPUS 8 eval
    fi

    if [ $do_chime3 == true ];then
	echo Performing WPE for CHiME3
	local/wpe/chime3_wpe.sh --resdir $CHIME3_ENH_CORPUS $CHIME3_CORPUS 6 dt05
	local/wpe/chime3_wpe.sh --resdir $CHIME3_ENH_CORPUS $CHIME3_CORPUS 6 et05
    fi
    
    if [ $do_reverb == true ];then
	echo Performing WPE for REVERB
	local/wpe/reverb_wpe.sh --resdir $REVERB_ENH_CORPUS $REVERB_CORPUS 8 dt RealData
	local/wpe/reverb_wpe.sh --resdir $REVERB_ENH_CORPUS $REVERB_CORPUS 8 et RealData
    fi
fi
wait


# Beamforming with beaformit 
enhan_ami=wpe8_bf
enhan_chime3=wpe6_bf
enhan_reverb=wpe8_bf

AMI_ENH_CORPUS=`pwd`/data/ami/${enhan_ami}/wav
CHIME3_ENH_CORPUS=`pwd`/data/chime3/${enhan_chime3}/wav #/data/audio/16kHz/isolated
REVERB_ENH_CORPUS=`pwd`/data/reverb/${enhan_reverb}/wav

if [ $stage -le 1 ]; then

    pushd local/beamformit
    ### NEED TO BE IMPLEMENTED!!!
    install_beamformit.sh
    popd

    beamformit_dir=/export/ws15-ffs-data/swatanabe/tools/beamformit/bin/BeamformIt-3.51
    if [ $do_ami == true ];then
	AMI_BF_IN_CORPUS=data_wpe8
	echo Performing beamformit for AMI
	local/beamformit/ami_beamformit.sh --beamformit-dir $beamformit_dir --nj 1 $AMI_BF_IN_CORPUS $enhan_ami $AMI_ENH_CORPUS
    fi

    if [ $do_chime3 == true ];then
	CHIME3_BF_IN_CORPUS=data_wpe6
	echo Performing BEAMFORMIT for CHiME3
	local/beamformit/chime3_beamformit.sh --beamformit-dir $beamformit_dir --nj 1 $CHIME3_BF_IN_CORPUS \
	     $enhan_chime3 dt05 $CHIME3_ENH_CORPUS 
	local/beamformit/chime3_beamformit.sh --beamformit-dir $beamformit_dir --nj 1 $CHIME3_BF_IN_CORPUS \
	     $enhan_chime3 et05 $CHIME3_ENH_CORPUS 
    fi
    
    if [ $do_reverb == true ];then
	REVERB_BF_IN_CORPUS=data_wpe8
	echo Performing BEAMFORMIT for REVERB
	local/beamformit/reverb_beamformit.sh --beamformit-dir $beamformit_dir --nj 1 $REVERB_BF_IN_CORPUS/MC_WSJ_AV_Dev \
	     $enhan_reverb dt RealData $REVERB_ENH_CORPUS
	local/beamformit/reverb_beamformit.sh --beamformit-dir $beamformit_dir --nj 1 $REVERB_BF_IN_CORPUS/MC_WSJ_AV_Eval \
	     $enhan_reverb et RealData $REVERB_ENH_CORPUS
    fi
fi

# Data preparation for decoding
if [ $stage -le 2 ]; then
    if [ $do_ami == true ]; then
	echo do ami

	mkdir -p data_${enhan_ami}/ami/local/annotations/
	cp ${AMI_EXP_DIR}/data/local/annotations/dev.txt data/ami/${enhan_ami}/local/annotations/
	cp ${AMI_EXP_DIR}/data/local/annotations/eval.txt data/ami/${enhan_ami}/local/annotations/
	
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

	    dataset=data/ami/$enhan_ami/$tset
	    fmllr_wrk_dir=${fmllr_decode_dir}/decode_ami_${lm_suffix}_${tset}_$enhan_ami
	    fmllr_data_dir=${fmllr_data}/ami/$enhan_ami/${tset}
	    mkdir -p $fmllr_wrk_dir
	    mkdir -p $fmllr_data_dir

	    local/run_fe_fmllr.sh --nj 10 --num-threads 3 \
					  $graph_dir \
					  $gmm_dir \
					  $dataset \
					  $fmllr_data_dir \
					  $fmllr_wrk_dir &
					  
	done
    fi
    ###############
    ###############
    # CHiME3 task
    if [ $do_chime3 == true ]; then
	
	echo feature extraction CHiME3 task
	
	lm_suffix=lm_tgpr_5k
	graph_dir=${fmllr_decode_dir}/graph_${lm_suffix}
	
	
	# Making decoding graph
	$highmem_cmd $graph_dir/mkgraph.log \
		     utils/mkgraph.sh data/lang_ami2chime3 \
		     $AMI_EXP_DIR/exp/$mic/tri4a $graph_dir
	
	for tset in dt et; do

	    dataset=data/chime3/$enhan_chime3/${tset}05_real
	    fmllr_wrk_dir=${fmllr_decode_dir}/decode_chime3_${lmsuffix}_${tset}05_real_$enhan_chime3
	    fmllr_data_dir=${fmllr_data}/chime3/${enhan_chime3}/${tset}05_real
	    
	    mkdir -p $fmllr_wrk_dir
	    mkdir -p $fmllr_data_dir

	    # Does feature extraction an FMLLR
	    local/run_fe_fmllr.sh --nj 4 --num-threads 3 \
					  $graph_dir \
					  $gmm_dir \
					  $dataset \
					  $fmllr_data_dir \
					  $fmllr_wrk_dir &
	    
	done  
    fi

    ###############
    ###############
    # REVERB task
    if [ $do_reverb == true ]; then
	
	echo feature extraction REVERB task
    
	for tset in dt et; do
	    #### !!! This should be checked !!!!! ####
	    #### Potential fix needed here #####
	    for dataset in `ls -d data/reverb/${enhan_reverb}/RealData_${tset}*` ; do
		echo $dataset

		lm_suffix=lm_tg_5k
		graph_dir=${fmllr_decode_dir}/graph_${lm_suffix}

		# Making decoding graph
		$highmem_cmd $graph_dir/mkgraph.log \
			     utils/mkgraph.sh data/lang_ami2reverb \
			     $AMI_EXP_DIR/exp/$mic/tri4a $graph_dir


		fmllr_wrk_dir=${fmllr_decode_dir}/decode_reverb_${lm_suffix}_`basename $dataset`_$enhan_reverb
		fmllr_data_dir=${fmllr_data}/reverb/$enhan_reverb/`basename $dataset`

		echo $fmllr_wrk_dir
		mkdir -p $fmllr_wrk_dir		
		mkdir -p $fmllr_data_dir

		# Does feature extraction an FMLLR
		local/run_fe_fmllr.sh --nj 4 --num-threads 3 \
					      $graph_dir \
					      $gmm_dir \
					      $dataset \
					      $fmllr_data_dir \
					      $fmllr_wrk_dir &

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

	    decode_dir=${dnn_decode}/decode_ami_${tset}_${lm_suffix}_${enhan_ami}
	    fmllr_data_dir=${fmllr_data}/ami/$enhan_ami/${tset}
	    scoring_opts=ami
    
            # DNN Decoding
	    steps/nnet/decode.sh --nj 10 --cmd "$decode_cmd" --config conf/decode_dnn.conf \
                --num-threads 3 \
                --nnet $dnn_dir/final.nnet --acwt $acwt \
                --srcdir $dnn_dir \
                $graph_dir $fmllr_data_dir $decode_dir &

	    # Scoring

	    # Requires the final.mdl to perform decoding
	    # XXX This still needs to be debuged!!! XXX #
	    echo $dnn_dir/final.mdl
	    ln -s $dnn_dir/final.mdl $dnn_decode

	    scoring_opts="--min-lmwt 4 --max-lmwt 15"

            echo local/score_ami.sh $scoring_opts --cmd "$decode_cmd" $fmllr_data_dir $graph_dir $decode_dir
	    local/score_asclite.sh --asclite true $scoring_opts --cmd "$decode_cmd" $fmllr_data_dir $graph_dir $decode_dir
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

	    decode_dir=${dnn_decode}/decode_chime3_${lm_suffix}_${tset}05_real_${enhan_chime3}
	    fmllr_data_dir=${fmllr_data}/chime3/${enhan_chime3}/${tset}05_real

	    scoring_opts=chime3
    
            # DNN Decoding
	    steps/nnet/decode.sh --nj 4 --cmd "$decode_cmd" --config conf/decode_dnn.conf \
                --num-threads 3 \
                --nnet $dnn_dir/final.nnet --acwt $acwt \
                --srcdir $dnn_dir \
                $graph_dir $fmllr_data_dir $decode_dir &

	    # Scoring
	    scoring_opts="--min-lmwt 4 --max-lmwt 15"
            local/score_chime3.sh $scoring_opts --cmd "$decode_cmd" $fmllr_data_dir $graph_dir $decode_dir
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


		decode_dir=${dnn_decode}/decode_reverb_${lm_suffix}_`basename $dataset`_$enhan_reverb
		fmllr_data_dir=${fmllr_data}/reverb/${enhan_reverb}/`basename $dataset`_$enhan_reverb

	
                # DNN Decoding
		steps/nnet/decode.sh --nj 4 --cmd "$decode_cmd" --config conf/decode_dnn.conf\
                    --num-threads 3 \
                    --nnet $dnn_dir/final.nnet --acwt $acwt \
                    --srcdir $dnn_dir \
	            $graph_dir $fmllr_data_dir $decode_dir &
		
		# Scoring
		scoring_opts="--min-lmwt 4 --max-lmwt 15"
                local/score_reverb.sh $scoring_opts --cmd "$decode_cmd" $fmllr_data_dir $graph_dir $decode_dir
	    done
	done
    fi
fi    

wait