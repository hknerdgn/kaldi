#!/bin/bash -u

# Copyright 2009-2012  Microsoft Corporation  Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0.

# Copyright 2015  Mitsubishi Electric Research Laboratories (MERL) (Author: Shinji Watanabe)
# Apache 2.0.

# Copyright 2015  NTT Corporation (Author: Marc Delcroix)
# Apache 2.0.


echo "$0 $@"  # Print the command line for logging

if [ $# != 0 ]; then
   echo "Usage: reverb_download_package.sh"
   exit 1;
fi

# Download REVERB tools
dir=`pwd`/data/local/reverb_tools
mkdir -p $dir # $reverb_tr_dir

URL1="http://reverb2014.dereverberation.com/tools/reverb_tools_for_Generate_mcTrainData.tgz"
URL2="http://reverb2014.dereverberation.com/tools/REVERB_TOOLS_FOR_ASR_ver2.0.tgz"
for f in $URL1 $URL2; do
    x=`basename $f`
    if [ ! -e $dir/$x ]; then
	wget $f -O $dir/$x || exit 1;
	tar zxvf $dir/$x -C $dir || exit 1;
    fi
done
URL3="http://reverb2014.dereverberation.com/tools/taskFiles_et.tgz"
x=`basename $URL3`
if [ ! -e $dir/$x ]; then
    wget $URL3 -O $dir/$x || exit 1;
    tar zxvf $dir/$x -C $dir || exit 1;
    cp -fr $dir/`basename $x .tgz`/* $dir/ReleasePackage/reverb_tools_for_asr_ver2.0/taskFiles/
fi

exit 0
