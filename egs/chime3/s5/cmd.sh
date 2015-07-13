# "queue.pl" uses qsub.  The options to it are
# options to qsub.  If you have GridEngine installed,
# change this to a queue you have access to.
# Otherwise, use "run.pl", which will run jobs locally
# (make sure your --num-jobs options are no more than
# the number of cpus on your machine.

# On Eddie use:
#export train_cmd="queue.pl -P inf_hcrc_cstr_nst -l h_rt=08:00:00"
#export decode_cmd="queue.pl -P inf_hcrc_cstr_nst  -l h_rt=05:00:00 -pe memory-2G 4"
#export highmem_cmd="queue.pl -P inf_hcrc_cstr_nst -l h_rt=05:00:00 -pe memory-2G 4"
#export scoring_cmd="queue.pl -P inf_hcrc_cstr_nst  -l h_rt=00:20:00"

#On WS15 cluster( AWS-EC2)
export train_cmd="queue.pl -l arch=*64* -q all.q"
export decode_cmd="queue.pl -l arch=*64* --mem 4G -q all.q"
export highmem_cmd="queue.pl -l arch=*64* --mem 4G -q all.q"
export scoring_cmd="queue.pl -l arch=*64* -q all.q"
#export cuda_cmd="queue.pl --gpu 1"
#export cuda_cmd="queue.pl -q gpu.q -l gpu=1"
export cuda_cmd=run.pl

# To run locally, use:
#export train_cmd=run.pl
#export decode_cmd=run.pl
#export highmem_cmd=run.pl
#export cuda_cmd=run.pl
