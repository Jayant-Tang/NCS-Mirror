# NCS-Mirror
## 简介

​	这是一个持续集成（CI）项目，运行在 GitHub Actions 平台上。用途是每天同步[nRF Connect SDK (NCS)](https://developer.nordicsemi.com/nRF_Connect_SDK/doc/latest/nrf/index.html)到[Gitee](https://gitee.com/)上。从而让国内的用户也可以快速稳定的下载到NCS。

​	NCS是一个复杂的项目，由多个Git仓库组成，其中某些Git仓库还具有Submodule仓库。NCS使用[West](https://developer.nordicsemi.com/nRF_Connect_SDK/doc/latest/zephyr/develop/west/index.html)作为多仓库管理工具。

​	NCS的Manifest记录在[nRF Connect SDK main repository (github.com)](https://github.com/nrfconnect/sdk-nrf)项目的`west.yml`文件中。本项目只会同步所有的正式Release版本（tag的正则表达式符合`^v[1-9]+\.[0-9]+\.[0-9]+$`即认为是正式版，如`v2.2.0`）到Gitee.com上。

​	你也可以Fork此项目，并修改配置，从而使此CI定时把NCS的所有子仓库拷贝到你的Gitee个人账号或企业账号上。

> 注意，此项目只会确保正式版的commit同步过去，但tag、分支名等不会同步过去。

## 如何从Gitee获取NCS？

​	你可以直接从`NCS-latest`分支获得最新的正式版：

```shell
mkdir ncs
cd ncs
west init -m https://gitee.com/jayant97/sdk-nrf --mr NCS-latest
```

​	你也可以获取指定的版本正式版。举例来说，**原本**从**GitHub**获取`v2.2.0`版本的命令为：

```shell
mkdir ncs
cd ncs
west init -m https://github.com/nrfconnect/sdk-nrf --mr v2.2.0
```

​	改为从Gitee镜像上进行下载，分支名变为`NCS-v2.2.0`

```shell
mkdir ncs
cd ncs
west init -m https://gitee.com/jayant97/sdk-nrf --mr NCS-v2.2.0
```

>**为什么分支的名称改变了？**
>
>​	原本的版本是一个tag，指向一个特定的commit。在镜像拷贝到Gitee之后，tag和commit id都不变。但是，此CI项目必须修改仓库中的`west.yml`和`.gitmodules`文件，让manifest中记录的其他仓库全部指向Gitee中的镜像仓库。这就必然导致产生新的commit id，于是脚本会新建`NCS-vX.X.X`分支，在提交了这些修改后，再推送到Gitee。
>
>​	在那之后，使用`git push -f`让`NCS-latest`分支强行切换到最新版本的分支上。

## 我可以在自己的GitHub账号上运行此CI脚本吗？

​	可以。并且，你还可以把同步的目标仓库改为其他的Gitee个人账户或企业仓库。

​	首先，你需要在GitHub上**Fork**此项目，让它成为**你的GitHub账户**上的一个远程仓库。

​	此项目的`.github/workflows/ncs-mirror.yml`是此CI项目的脚本文件。其开头有一些环境变量可供修改：

```yaml
env:
  PYTHON_VER: 3.8
  GITEE_USER: jayant97
  GITEE_TOKEN: ${{ secrets.GITEE_API_TOKEN }}
  GITEE_PRI: ${{ secrets.GITEE_SSH_PRV }}
  GIT_USER: Jayant.Tang
  GIT_EMAIL: jayant.tang@nordicsemi.no
  NCS_MANIFEST: https://github.com/nrfconnect/sdk-nrf.git
```

如果你要修改账户，需要修改以下项目：

- `GITEE_USER`：你的Gitee用户名
- `GITEE_TOKEN`：需要用此Token来调用Gitee API来执行创建新仓库的操作。这里使用的是Gitee账户设置--- 安全设置 --- 私人令牌 中创建的私人令牌。权限只需要`projects`（查看、创建、更新项目）。
- `GITEE_PRI`：你的Gitee账户的ssh私钥。与其成对的公钥必须**已经**上传到你的Gitee账户中。你需要确保这个私钥可以ssh访问到你的Gitee远程仓库。

> ​	API Token的`Name`需设置为`GITEE_API_TOKEN`；SSH私钥的`Name`需设置为`GITEE_SSH_PRV`。设置完毕后，Action脚本中就可以访问到这些密钥。GitHub Actions会确保这些密钥一定不会被打印出来。

## 此项目是如何实现的？

### 获取sdk-nrf的所有正式版列表

​	在这里，**正式版**被定义为“tag符合正则表达式`^v[1-9]+\.[0-9]+\.[0-9]+$`”的所有revision。也就是版本号大于等于`v1.0.0`的不带后缀的版本tag。

​	采用以下命令可以创建一个空仓库并获取`sdk-nrf`的所有正式版版本号：

```shell
mkdir sdk-nrf
cd sdk-nrf
git init
git remote add origin https://github.com/nrfconnect/sdk-nrf.git
git ls-remote --tags origin | awk '{print $2}' | sed -e "s#^refs/tags/##" | grep -E "^v[1-9]+\.[0-9]+\.[0-9]+$" > ../all-tags.txt
```



### 获取NCS所有正式版本的所有成员仓库及Submodule的URL

​	确保已安装最新版NCS，并已经位于NCS根目录中：

```shell
echo "https://github.com/nrfconnect/sdk-nrf.git" > ~/repo-list-raw.txt
for version in $(cat ../all-tags.txt); do
    cd nrf
    git checkout $version
    cd ..
    west update
    west list -f "{url}" | grep -E "^https://" >> ~/repo-list-raw.txt
    west forall -c "git submodule foreach --recursive \"git remote -v | awk '{print \\\$2}' | sed 's#\\\\.git##' | uniq >> ~/repo-list-raw.txt\"" 
done
```

​	以上命令会把NCS所有版本的所有成员仓库及Submodule的URL保存到`~/repo-list-raw.txt`中。

> 备注：
>
> - `west list`命令会列举west所有成员仓库的信息。`west list -f {url}`只会列出URL。但sdk-nrf是主仓库，其URL不会被列出，因此用`echo`命令手动记录。
> - `west forall -c "COMMAND"`命令会在所有的west成员仓库中执行`COMMAND`命令
> - `git submodule foreach --recursive "COMMAND"`会在一个git仓库的所有submodule中执行COMMAND命令
> - `git remote -v | awk '{print $2}' | sed 's#\.git##' |uniq` 会列出一个git仓库的远程仓库的地址。某些仓库会有多个相同地址的远程仓库，但是后缀名有`.git`之分，这里需要去除`.git`后缀，从而确保唯一性
> - 这里命令嵌套了两层双引号，需注意`$`、`\`、和`"`都需要转义1到2层。

对URL列表进行整理、排序、去重：

```shell
cat ~/repo-list-raw.txt | sort -f | uniq > ~/repo-list.txt
```



###  在Gitee上创建空仓库

​	使用Gitee API来创建仓库，详情参考：[Gitee API 文档](https://gitee.com/api/v5/swagger#/postV5UserRepos)
```shell
curl --connect-timeout 15 --max-time 30 --retry 3 --retry-delay 2 -X POST \
          --header 'Content-Type: application/json;charset=UTF-8' \
          'https://gitee.com/api/v5/user/repos' \
          -d '{"access_token":"${{ env.GITEE_TOKEN }}","name":"'$line'","description":"这是一个镜像仓库，定时同步更新。详情请参考${{ github.server_url }}/${{ github.repository }}","has_issues":"false","has_wiki":"false","can_comment":"false","auto_init":"false","path":"'$line'","private":"true"}'
```

> 备注：
>
> - 通过Gitee API创建的仓库，只能是私有（单仓库限制500M）。需要后续再修改为公有（单仓库限制1G）
> - 空仓库（没有branch的仓库）无法被修改为公有



### 修改内容并推送到Gitee

这部分内容在脚本`push-to-gitee.sh`中实现。

在所有NCS成员仓库以及Submodule中遍历执行以下操作：

1. 添加远程仓库
   ```shell
   git remote add gitee-$version git@gitee.com:$gitee_user/$name
   ```

   > 注意，这里的name：
   >
   > - 如果是west成员仓库，则要使用`west list . -f "{url}"`，然后从URL中提取
   > - 如果是submodule，则要从`git remote -v`中提取
   >
   > ​    west成员仓库不能从后者提取。因为west update时，如果本地找得到revision，则不会从远端重新拉取。会出现`git remote -v`和`west list . -f "{url}"`的地址不相同的情况。典型的例如`sdk-zephyr`和` fw-nrfconnect-zephyr`，他们都是zephyr仓库，但是是不同的remote，分别属于2.x版本和1.x版本。

2. 在每个revision中创建`NCS-$version`分支

   ```shell
   git checkout -b NCS-$version
   ```

3. 修改`west.yml`和`.gitmodules`中的地址与Revision，将其重定向到Gitee上镜像仓库的`NCS-$version分支上`，然后commit

   ```shell
   for file in $(ls -1a | grep "west.yml"); do
       echo "Modifying the $file"
       sed -i 's#url-base:.*https://.\+/.\+#url-base: https://gitee.com/'$gitee_user'#' west.yml > /dev/null
       sed -i 's#revision:.\+#revision: NCS-'$version'#' west.yml > /dev/null
       git add .
       git commit -m "modify url of NCS-$version"
       git diff-tree --cc HEAD
   done
   
   for file in $(ls -1a | grep ".gitmodules"); do
       echo "Modifying the $file"
       sed -i 's#url.*=.*https://.\+/.\+/#url = https://gitee.com/'$gitee_user'/#' .gitmodules > /dev/null
       sed -i  's#branch.*=.*#branch = NCS-'$version'#' .gitmodules > /dev/null
       git add .
       git commit -m "modify url of NCS-$version"
       git diff-tree --cc HEAD
   done
   ```

4. 推送

   ```shell
   git push gitee-$version HEAD:refs/heads/NCS-$versio
   ```

> ​	此脚本默认只推送自己生成的`NCS-vX.X.X`分支，从而节约时间。若想把仓库原本的tag全部推送，则需解开脚本中`git push gitee-$version --tags`的注释。

5. 修改`NCS-latest`分支的指向

   ```shell
   if [ "$version" == "$latest_ver" ]; then
       git push -f gitee-$version HEAD:refs/heads/NCS-latest
   fi
   ```

   

### 修改仓库权限

​	由于仓库已经不再是空仓库，因此可以把仓库权限设置为公有，从而使所有人都可以下载的到。然后把默认分支设为`NCS-latest`。同样使用：[Gitee API](https://gitee.com/api/v5/swagger#/patchV5ReposOwnerRepo)

```shell
curl --connect-timeout 15 --max-time 30 --retry 3 -X PATCH --header 'Content-Type: application/json;charset=UTF-8' 'https://gitee.com/api/v5/repos/${{ env.GITEE_USER }}/'$line'' \
          -d '{"access_token":"${{ env.GITEE_TOKEN }}","name":"'$line'","has_issues":"false","has_wiki":"false","can_comment":"false","private":"false","default_branch":"NCS-latest"}'
```

### 任务的缓存与加速

​	此CI项目使用[actions/cache](https://github.com/actions/cache)来缓存NCS。缓存的key由前述的正式版本号列表进行hash生成。也即是说，如果NCS不发布正式版，则key不会变化，此CI项目就会一直使用缓存的NCS，而不是下载新的NCS。

​	当缓存命中时，后续的创建、推送的任务都不会执行，从而节省CI任务的时间。
