#!/bin/bash

input_file=$1

cat "$input_file" | while read line; do
  repo=$(echo $line | sed 's#^https://.\+\.com/\(.*\)/\(.*\)#\2#' | sed 's#[.]git$##')
  echo "{\"url\":\"$line\",\"repo\":\"$repo\"}"
done > merge.json