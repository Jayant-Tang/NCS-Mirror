#!/bin/bash

if [ ! -d .git ]; then
  echo "Error: Not a Git repository."
  exit 1
fi
git remote -v | awk '{print $2}' | uniq >> ~/repo-list-raw.txt
git submodule foreach --recursive "git remote -v | awk '{print \$2}' | uniq >> ~/repo-list-raw.txt"