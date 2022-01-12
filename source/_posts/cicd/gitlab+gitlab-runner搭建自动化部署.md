---
title: gitlab+gitlab-runner搭建自动化部署
date: 2022-01-12 11:40:35
author:  
img: https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121202334.png
top: true
hide: false
cover: true
coverImg: https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121153157.png
toc: true
mathjax: false
summary: 随着工作量越来越大，我们需要保证我们的工作效率的同时保证我们的代码的质量，所以我们需要一些自动化的东西加入到我们的工作中
自动化部署、自动化测试、自动化通知等
categories: cicd
tags:
  - cicd
  - gitlab
  - gitlab-runner
  - kubernetes
---

# 前言

实现自动部署
* 开发人员上传代码到gitlab
* gitlab-runner 检测到操作便开始自动部署
* 部署检测代码的是java还是web，检测需要部署的端口，实现根据代码和端口部署
* 部署完成发送信息到企业微信
# 分析实现步骤
* 安装gitlab-runner
* 在需要部署java程序的机器上绑定 ，tags为test部署java程序
* 在需要部署web程序的机器上绑定 ，tags为test部署web程序
* 编写.gitlab-ci.yml放在项目的第一级目录
* 编写shell脚本实现部署
* 实现企业微信报警
* 检测是否自动部署
# 安装gitlab
[Centos7搭建gitlab](https://www.jianshu.com/p/8d981d1bff9a)
# 部署gitlab-runner
> 使用gitlab-runner实现自动部署
```
# 安装repository
curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh | sudo bash
# 安装gitlab-runner
yum install gitlab-runner
```
> 在需要部署的机器上注册
# url以及token获取
![url以及token位置](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121206846.png)

```
[root@test2 SHELL]# gitlab-runner register
Runtime platform                                    arch=amd64 os=linux pid=53435 revision=d0b76032 version=12.0.2
Running in system-mode.                            
                                                   
Please enter the gitlab-ci coordinator URL (e.g. https://gitlab.com/):
http://192.168.0.71/gitlab/   #输入URL
Please enter the gitlab-ci token for this runner:
-rwbBw2y7GmL7smxuoxt  #输入TOKEN
Please enter the gitlab-ci description for this runner:
[test2.laozios.com]: test    #后面脚本需要用到
Please enter the gitlab-ci tags for this runner (comma separated):
test                                   #后面脚本需要用到
Registering runner... succeeded                     runner=-rwbBw2y
Please enter the executor: parallels, kubernetes, virtualbox, docker+machine, docker-ssh+machine, docker, docker-ssh, shell, ssh:
shell                                 #通过shell
Runner registered successfully. Feel free to start it, but if it's running already the config should be automatically reloaded! 
```
![执行过程](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121206944.png)

> 查看结果
* 命令行查看
```
gitlab-runner list 
```
![查看是否绑定成功](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121206022.png)
* gitlab页面查看
![查看结果](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121206830.png)
# 重复上面步骤
* 刚刚绑定的是test应该为对于的【java】【web】
# 编写.gitlab-ci.yml文件
```
stages:
  - deploy
  - notice-success
  - notice-failure


package:Project:
  stage: deploy
  only:
    - /^feature.*$/
    - /^release.*$/
  variables:
    ############必须配置############
    ## 连接API的接口以及NGINX端口地址
    APIPORT: 9992
    NGINXPORT: 803

    #项目名称即git名称
    projectName: $CI_PROJECT_NAME
    #git idea 拉代码的git地址
    gitUrl: $CI_REPOSITORY_URL
    #工程所在目录
    baseDir: '/home/gitlab-runner/${CI_PROJECT_NAME}'
    ############选配############
    #打包所在目录
    buildDir: '/home/gitlab-runner/builds'
    #打包环境
    branch: $CI_COMMIT_REF_NAME
  script:
    - bash /SHELL/installPack $CI_PROJECT_NAME  $CI_REPOSITORY_URL  $CI_COMMIT_REF_NAME $APIPORT  $NGINXPORT
  tags:
    - web

notice_job:Project:
  variables:
    branch: $CI_COMMIT_REF_NAME
    projectName: $CI_PROJECT_NAME
  stage: notice-failure
  only:
    - /^feature.*$/
    - /^release.*$/
  script:
    - if [[ ${branch:0:8} = "feature/" ]];then env="dev" ;elif [[ ${branch:0:8} = "release-" ]];then  env="test";fi
    - python3 /SHELL/buildNotice.py $env $branch 失败  $projectName
  when: on_failure
  tags:
    - web

notice_job:Project:
  variables:
    branch: $CI_COMMIT_REF_NAME
    projectName: $CI_PROJECT_NAME
  stage: notice-success
  only:
    - /^feature.*$/
    - /^release.*$/
  script:
    - if [[ ${branch:0:8} = "feature/" ]];then env="dev" ;elif [[ ${branch:0:8} = "release-" ]];then  env="test";fi
    - python3 /SHELL/buildNotice.py $env $branch  成功  $projectName
  when: on_success
  tags:
    - web
```
 > 实现环境判断并实现部署脚本
```
#!/bin/bash
## 拉取代码进行安装

########获取编译函数###########
source /SHELL/buildPack 
############必须配置############
#项目名称即git名称
projectName=$1
#git idea 拉代码的git地址
gitUrl=$2
#打包分支
branch=$3
APIPORT=$4
NGINXPORT=$5

###########初始化参数###########

###############################
if [ -z $APIPORT ];then
   APIPORT="9991"
fi
if [ -z $NGINXPORT ];then
   NGINXPORT="802"
fi
###根据分支判断环境
if [[ ${branch:0:8} = "feature/" ]];then
    env="dev"
    APIPORT=$APIPORT
    NGINXPORT=$NGINXPORT
elif [[ ${branch:0:8} = "release/" ]];then
    env="test"
    APIPORT="9999"
    NGINXPORT="801"
fi

###编译目录
buildDir="/home/gitlab-runner/$env/$projectName/$branch"

###进行部署###
###判断项目编译目录是否存在
if [ ! -d ${buildDir} ];then
    mkdir ${buildDir} -p
fi
cd ${buildDir}

###该分支目录名字已经存在则删除该目录重新拉起
if [ -e $projectName ];then
    rm -rf ${buildDir}/${projectName}
fi
## 拉取分支到本地
git  clone $gitUrl
## 判断是否拉取成功，不成功退出
if [ '0' != $? ]; then 
    echo "注意：更新发生错误！" 
    exit 1
fi
## 进入项目并且切换分支
cd $projectName && git checkout $branch
if [ '0' != $? ]; then 
    echo "注意：切换分支发生错误！"
    exit 3
fi
## 进行编译
if [ $projectName = "web" ];then
  ## 修改配置文件
  echo $NGINXPORT
  sed -i "s/\(^axios.defaults.baseURL = \).*/\1 \'http:\/\/192.168.0.xxx:$NGINXPORT\/api\\'/" src/main.js
  ## 进行web编译
  buildweb  
  ## 编译成功进行文件移动
  if [ -d /ENV/$env/web/$NGINXPORT ];then
    ## 文件存在：判断移动目录
    if [ ! -d /ENV/$env/BACKUP/web/$NGINXPORT ];then
        mkdir /ENV/$env/BACKUP/web/$NGINXPORT -p 
    fi
    ## 文件存在：移动到上面目录
    mv /ENV/$env/web/$NGINXPORT /ENV/$env/BACKUP/web/$NGINXPORT/web_`date "+%Y_%m_%d_%H_%M_%S"` && \
    mv ${buildDir}/$projectName/dist /ENV/$env/web/$NGINXPORT
  else
    echo "修改了端口先通知运维"
    exit 6
  fi
  sed -i "s/\(proxy_pass.*:\).*/\1$APIPORT;/" /etc/nginx/conf.d/$NGINXPORT.conf 
  nginx -t && nginx -s reload
  
elif [ $projectName = "java" ];then
  ## 进行java编译
  buildjava
  ## 编译成功进行文件移动
  if [ ! -d ${buildDir}/${projectName}/$branch/"$projectName"_build ];then
     mkdir ${buildDir}/$projectName"_build" -p
  fi
  cd ${buildDir}/$projectName"_build"
  unzip -oq ${buildDir}/$projectName/lw-admin/target/lw-admin.war -d ./
  sed -i "s/\(active:\).*/\1 $env/" WEB-INF/classes/application.yml  
  ## 备份以前的文件
  if [ -d /ENV/$env/tomcat/$APIPORT/ROOT ];then
    ## 文件存在：判断移动目录
    if [ ! -d /ENV/$env/BACKUP/tomcat/$APIPORT ];then
        mkdir /ENV/$env/BACKUP/tomcat/$APIPORT -p 
    fi
    ## 文件存在：移动到上面目录
    mv /ENV/$env/tomcat/$APIPORT/ROOT /ENV/$env/BACKUP/tomcat/$APIPORT/ROOT_`date "+%Y_%m_%d_%H_%M_%S"` && \
    echo "`ls ${buildDir}/"$projectName"_build`"
    echo "`pwd`"
    mv ${buildDir}/"$projectName"_build /ENV/$env/tomcat/$APIPORT/ROOT
    docker restart "$APIPORT"_tomcat
  else
    echo "修改了端口先通知运维"
    exit 6
  fi
else
  ## 没有在这次自动化规划之内
  echo "该项目$projectName没有该这样自动化部署之内"
  exit 3
fi
```
> 实现编译
```
[root@test2 SHELL]# vim buildPack 

##编译web
buildweb(){
    cnpm  install && \
    cnpm rebuild node-sass && cnpm run build
    if [ $? = 0 ];then
       echo "编译成功"
    else
       echo "编译失败"
       exit 4
    fi
}

##编译java
buildjava(){
    mvn clean && \
    mvn install && \
    mvn package
    if [ $? = 0 ];then
       echo "编译成功"
    else
       echo "编译失败"
       exit 4
    fi
}

```
>获取企业微信信息
* 创建应用
![创建应用](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121206064.png)
* 查看绑定信息
![绑定信息](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121206434.png)


> 实现企业微信通知
```
[root@test2 SHELL]# cat  buildNotice.py 
#!/usr/bin/python
# -*- coding: utf-8 -*-

import json
import requests
import sys
import time

##参数
corpid = "wwXXXXX"
secret = "LXXXXXXa64Bc"
agentid = "100XXX2"
#corpid = "wwXXXX2c"
#secret = "_fhXXXXXXXXp-VpWvJc9U78"
#agentid = "100XXXX3"

localtime = time.asctime(time.localtime(time.time()))



class WeChat(object):
    def __init__(self, corpid, secret, agentid):
        self.url = "https://qyapi.weixin.qq.com"
        self.corpid = corpid
        self.secret = secret
        self.agentid = agentid

    # 获取企业微信的 access_token
    def access_token(self):
        url_arg = '/cgi-bin/gettoken?corpid={id}&corpsecret={crt}'.format(
            id=self.corpid, crt=self.secret)
        url = self.url + url_arg
        response = requests.get(url=url)
        text = response.text
        self.token = json.loads(text)['access_token']

    # 构建消息格式
    def messages(self, msg):
        values = {
            "touser": '@all',
            "msgtype": 'text',
            "agentid": self.agentid,
            "text": {'content': msg},
            "safe": 0
        }
        # python 3
        self.msg = (bytes(json.dumps(values), 'utf-8'))
        # python 2
        #self.msg = json.dumps(values)

    # 发送信息
    def send_message(self, msg):
        self.access_token()
        self.messages(msg)

        send_url = '{url}/cgi-bin/message/send?access_token={token}'.format(
            url=self.url, token=self.token)
        response = requests.post(url=send_url, data=self.msg)
        errcode = json.loads(response.text)['errcode']

        if errcode == 0:
            print('Succesfully')
        else:
            print('Failed')


# 开发环境|测试环境 WEB|TEST 部署成功|部署失败
#  python3 /SHELL/buildNotice.py dev web  成功
def send():
    print(sys.argv)
    msg = "@所有小伙伴们：\r\n{_time}\r\n环境：{_env} \r\n分支：{_pro} \r\n状态：{_status}\r\nREPO:{_repo}\r\n有问题请@运维小伙伴。谢谢".format(_time=localtime,_env=sys.argv[1],_pro=sys.argv[2],_status=sys.argv[3],_repo=sys.argv[4])
    #msg="jamestest"
    wechat = WeChat(corpid, secret, agentid)
    wechat.send_message(msg)
send()
```
# 推送代码实现部署

![查看流程线](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121206236.png)
![查看执行步骤](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121206677.png)
![查看部署流程](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121207461.png)
![查看通知](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121207819.png)

![企业微信通知](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121207908.png)

# 进阶优化问题
* 安装时候
```
/usr/bin/gitlab-ci-multi-runner run --working-directory /home/gitlab-runner --config /etc/gitlab-runner/config.toml --service gitlab-runner --syslog --user gitlab-runner
```
* 如何修改gitlab-runner的工作路径
```
--working-directory /home/gitlab-runner
```
* 修改用户执行用户
```
--user gitlab-runner
```
* 配置文件
```
--config /etc/gitlab-runner/config.toml
```
# 如何查询
```
ps aux|grep gitlab-runner
root      9217  2.9  0.0  44996 12988 ?        Ssl  Jul31 161:47 /usr/local/bin/gitlab-runner run --working-directory /home/gitlab-runner --config /etc/gitlab-runner/config.toml --service gitlab-runner --syslog --user gitlab-runner
root     21162  0.0  0.0 112712   984 pts/4    S+   18:52   0:00 grep --color=auto gitlab-runner
```
## 通过启动文件修改
```
vim /etc/systemd/system/gitlab-runner.service
[Unit]
Description=GitLab Runner
After=syslog.target network.target
ConditionFileIsExecutable=/usr/lib/gitlab-runner/gitlab-runner

[Service]
StartLimitInterval=5
StartLimitBurst=10
ExecStart=/usr/lib/gitlab-runner/gitlab-runner "run" "--working-directory" "/BUILD" "--config" "/etc/gitlab-runner/config.toml" "--service" "gitlab-runner" "--syslog" "--user" "root"





Restart=always
RestartSec=120

[Install]
WantedBy=multi-user.target
```
# 重启
```

systemctl daemon-reload
systemctl start gitlab-runner
```
[参考](http://fidding.me/article/111)

# 参考文档
[参考文档](https://docs.gitlab.com/runner/install/linux-repository.html)
[变量](https://docs.gitlab.com/ce/ci/variables/predefined_variables.html)