#!/bin/bash
version=$1
gitee_user=$2

name=$(git remote -v | awk '{print $2}' | grep -E '^https' | uniq | sed -e "s#^https://.\+\.com/\(.*\)/\(.*\)#\2#" | tail -n 1)

echo "repo-name:{$name}"

git remote add gitee git@gitee.com:$gitee_user/$name
git remote -v


git push gitee HEAD:refs/heads/NCS-$version
#git push gitee --tags

sleep 2