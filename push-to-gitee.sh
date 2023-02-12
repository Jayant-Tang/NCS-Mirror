#!/bin/bash
version=$1
gitee_user=$2


west list . >/dev/null 2>&1

if [ $? -ne 0 ];then
    # this repo is a submodule, use git to get the name
    name=$(git remote -v | awk '{print $2}' | grep -E '^https' | uniq | sed -e "s#^https://.\+\.com/\(.*\)/\(.*\)#\2#" | tail -n 1)
    echo "[$name] is a submodule"
else
    # this repo is member of west manifest, use west to get the correct name
    name=$(west list -f {url} . | grep -E '^https' | uniq | sed -e "s#^https://.\+\.com/\(.*\)/\(.*\)#\2#" | tail -n 1)
    
    # the url of manifest is N/A, so the result of grep is nothing.
    if [ -z $name ];then
        name="sdk-nrf"
    fi

    echo "[$name] is a west member"
fi

echo "repo-name:[$name]"

git remote add gitee-$version git@gitee.com:$gitee_user/$name
git remote -v

# create a new branch and switch to it
git checkout -b NCS-$version

# change the url in .gitmodules and west
for file in $(ls -la | grep "west.yml"| awk '{print $9}'); do
    echo "Modifying the $file"
    sed 's#url-base:.*https://.\+/.\+#url-base: https://gitee.com/'$gitee_user'#' west.yml > /dev/null
    sed 's#revision:.\+#revision: NCS-'$version'#' west.yml > /dev/null
done

for file in $(ls -la | grep ".gitmodules" | awk '{print $9}'); do
    sed 's#url.*=.*https://.\+/.\+/#url = https://gitee.com/'$gitee_user'/#' .gitmodules > /dev/null
    sed 's#branch.*=.*#branch = NCS-'$version'#' .gitmodules > /dev/null
done

# commit
git add .
git commit -m "modify url of NCS-$version"
git diff-tree --cc HEAD

# push
git push gitee-$version HEAD:refs/heads/NCS-$version
#git push gitee --tags

sleep 2