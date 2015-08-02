export KALDI_ROOT=/home/herdogan/kaldi
export PATH=$PWD/utils/:$KALDI_ROOT/src/bin:$KALDI_ROOT/tools/openfst/bin:$KALDI_ROOT/src/fstbin/:$KALDI_ROOT/src/gmmbin/:$KALDI_ROOT/src/featbin/:$KALDI_ROOT/src/lm/:$KALDI_ROOT/src/sgmmbin/:$KALDI_ROOT/src/sgmm2bin/:$KALDI_ROOT/src/fgmmbin/:$KALDI_ROOT/src/latbin/:$KALDI_ROOT/src/nnetbin:$KALDI_ROOT/src/nnet2bin/:$KALDI_ROOT/src/kwsbin:$KALDI_ROOT/tools/irstlm/bin/:$KALDI_ROOT/tools/kaldi_lm/:$PWD:$PATH
export LC_ALL=C

LMBIN=$KALDI_ROOT/tools/irstlm/bin
SRILM=$KALDI_ROOT/tools/srilm/bin/i686-m64
BEAMFORMIT=$KALDI_ROOT/tools/BeamformIt-3.51

export PATH=$PATH:$LMBIN:$BEAMFORMIT:$SRILM

LD_LIBRARY_PATH=$KALDI_ROOT/tools/openfst/lib:$LD_LIBRARY_PATH

# For CNTK.
export LD_LIBRARY_PATH=/export/ws15-dnn-data/tools/acml/gfortran64/lib/:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/export/ws15-ffs-data/herdogan/cntk/bin/:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/export/ws15-ffs-data/herdogan/kaldi/src/lib/:$LD_LIBRARY_PATH
export PATH=/export/ws15-ffs-data/herdogan/cntk/bin/:$PATH


