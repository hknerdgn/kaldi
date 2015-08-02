#!/bin/bash


while read line; do
mkdir -p $line
done < $1
