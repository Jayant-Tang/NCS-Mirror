# NCS-Mirror
## 简介

​	这是一个持续集成（CI）项目，运行在 GitHub Actions 平台上。用途是每天同步[nRF Connect SDK (NCS)](https://developer.nordicsemi.com/nRF_Connect_SDK/doc/latest/nrf/index.html)到[Gitee](https://gitee.com/)上。从而让国内的用户也可以快速稳定的下载到NCS。

​	NCS是一个复杂的项目，由多个Git仓库组成，其中某些Git仓库还具有Submodule仓库。NCS使用[West](https://developer.nordicsemi.com/nRF_Connect_SDK/doc/latest/zephyr/develop/west/index.html)作为多仓库管理工具。

​	NCS的Manifest记录在[nRF Connect SDK main repository (github.com)](https://github.com/nrfconnect/sdk-nrf)项目的`west.yml`文件中。本项目只会同步所有的正式Release版本（tag的正则表达式符合`^v[1-9]+\.[0-9]+\.[0-9]+$`即认为是正式版，如`v2.2.0`）到Gitee.com上。

​	你也可以Fork此项目，并修改配置，从而使此CI定时把NCS的所有子仓库拷贝到你的Gitee个人账号或企业账号上。

> 注意，此项目只会同步仓库的所有tag，而不会同步分支。

## 如何从Gitee获取NCS？

待补充

## 如何让此项目定时同步NCS到我个人或企业的Gitee账号上？

待补充

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



### 在Gitee上创建空仓库

使用Gitee API来创建仓库，详情参考：[Gitee API 文档](https://gitee.com/api/v5/swagger#/postV5UserRepos)

> 备注：
>
> - 通过Gitee API创建的仓库，只能是私有（单仓库限制500M）。需要后续再修改为公有（单仓库限制1G）
> - 空仓库（没有branch的仓库）无法被修改为公有



### 推送每个仓库的每个版本的Revision到Gitee

考虑到以下限制：

- push内容要尽可能少，只push必要内容，因此最好单独push每个版本需要用到的revision（tag）
- 必须要推送分支，而不能只推送标签。否则将被Gitee认定为空仓库，后续无法把仓库修改为公有
- 各个成员仓库和Submodule的默认分支命名不统一（`master`、`main`和其他），难以准确获取其原始默认分支名

本项目的解决方案为：

- 对于每个版本的每个仓库，在推送到Gitee时，推送到新的`NCS-vx.x.x`分支上。例如，NCS`v2.2.0`版本的所有子仓库的revision，在Gitee上都对应`NCS-v2.2.0`分支。具体来说，就是在每个子仓库中执行：
  ```shell
  git push gitee HEAD:refs/heads/NCS-vX.X.X
  ```

总的命令流程为：

```shell
for version in $(cat ../all-tags.txt); do

    cd nrf
    git checkout $version
    cd ..
    west update
    west forall -c "$(pwd)/../push-to-gitee.sh $version $GITEE_USER"
    west forall -c "git submodule foreach --recursive \"$(pwd)/../push-to-gitee.sh $version $GITEE_USER\""

done
```

​	其中`push-to-gitee.sh`脚本在本CI项目中，作用是把gitee添加到远程仓库，并推送所有tag。同时，把当前revision推送到`refs/heads/NCS-vX.X.X`分支上。

> 这一步骤会检出每个版本，并执行`west update`，同时还要在每个仓库中递归执行push，非常耗时。



### 修改仓库权限

​	由于仓库已经不再是空仓库，因此可以把仓库权限设置为公有，从而使所有人都可以下载的到。同样使用：[Gitee API 文档](https://gitee.com/api/v5/swagger#/patchV5ReposOwnerRepo)



### 执行“关系的拷贝”

​	除了要把每个仓库同步到Gitee之外，还要把“仓库之间的关系”修改到Gitee上。否则Gitee上仓库的Submodule仍然指向Github或Google等。

​	这就需要把`west.yml`和`.submodules`文件中记录的仓库地址改到Gitee上同步的地址。



### 任务的缓存与加速

​	此CI项目使用[actions/cache](https://github.com/actions/cache)来缓存NCS。缓存的key由前述的正式版本号列表进行hash生成。也即是说，如果NCS不发布正式版，则key不会变化，此CI项目就会一直使用缓存的NCS，而不是下载新的NCS。

​	当缓存命中时，后续的创建、推送的任务都不会执行，从而节省CI任务的时间。
