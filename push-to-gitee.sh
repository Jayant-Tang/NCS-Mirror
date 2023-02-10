#!/bin/bash -v
version=$1
gitee_user=$2

echo $2
echo $gitee_user



name=$(git remote -v | awk '{print $2}' | grep -E '^https' | uniq | sed -e "s#^https://.\+\.com/\(.*\)/\(.*\)#\2#")
echo $name
git remote add gitee git@gitee.com:$gitee_user/$name
git remote -v
git push gitee --mirror
# git push gitee HEAD:refs/tags/NCS-$version
# git checkout `git rev-list --max-parents=0 HEAD | tail -n 1`
# git checkout -b init
# git push gitee HEAD:refs/heads/init