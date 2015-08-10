#!/bin/bash

wavdir=/data2/erdogan/chime3/data

for dataset in dt05 et05 tr05; do
  for ch in 1 2 3 4 5 6; do
    local/channel_adapt_chime3_data.sh --nj 4 --wavdir $wavdir ${dataset}_real ch0 ch${ch} reverb_ch${ch}
  done
done
