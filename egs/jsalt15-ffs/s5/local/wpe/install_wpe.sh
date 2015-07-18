#!/bin/bash

# Script to install wpe package
# It requires to have the package
# It is for the moment only available on demand by e-mail
# Send request to marc.delcroix@lab.ntt.co.jp

toolname=wpe_v1.2
wpe_tgz=/export/ws15-ffs-data/mdelcroix/tools/${toolname}.tgz

tar zxvf $wpe_tgz -C . 

cp ${toolname}/wpe.p .
cp ${toolname}/wpe_wavio.p .
cp ${toolname}/settings/conf* conf
cp ${toolname}/run_*.m .