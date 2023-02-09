#!/bin/bash

input_file=$1

cat "$input_file" | while read line; do
  user=$(echo $line | sed 's#https://github.com/\(.*\)/\(.*\)#\1#')
  repo=$(echo $line | sed 's#https://github.com/\(.*\)/\(.*\)#\2#' | sed 's#[.]git$##') 
  echo "{\"src\":\"$user\",\"repo\":\"$repo\"}"
done | \
jq -s add | \
jq -c 'reduce .[] as $i ({}; .[$i.src]= ($i + .[$i.src] |= {"repo": $i.repo})) | to_entries[] | {src: .key, repo: .value.repo}' > ~/merge.json 
