---
title: k8s 通过helm部署gitlab-runner
date: 2022-01-11 11:40:35
author:  
img: https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121202334.png
top: true
hide: false
cover: true
coverImg: https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121153157.png
toc: true
mathjax: false
summary: 通过gitlab-runner实现自动化部署，实现当程序员推送代码后，gitlab-runner实现自动拉取代码并编译打包上传镜像以及自动部署
categories: cicd
tags:
  - cicd
  - gitlab
  - gitlab-runner
  - kubernetes
---



# 前言

# gitlab 需要提供的参数 URL+TOKEN

![gitlab-runner 需要参数](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/cicd/202201121334232.png)


# 部署相关
##  安装helm
[安装helm安装部署参考](https://www.jianshu.com/p/9f294f654433)
## 通过helm安装gitlab-runner
>下载gitlab-runner
```
git clone https://github.com/haoshuwei/ack-gitlab-runner.git
```
> 修改文件values.yaml


```
gitlabUrl: gitlab服务器上管理页面上的URL
runnerRegistrationToken: gitlab服务器管理页面的token
```
> 现在直接打包部署会出现报错
- [解决办法参考](https://www.jianshu.com/p/21d916643560)
- 修改配置文件
```
vim templates/deployment.yaml
apiVersion: apps/v1                                        # 修改
kind: Deployment
metadata:
  name: {{ template "gitlab-runner.fullname" . }}
  labels:
    app: {{ template "gitlab-runner.fullname" . }}
    chart: "{{ .Chart.Name }}-{{ .Chart.Version }}"
    release: "{{ .Release.Name }}"
    heritage: "{{ .Release.Service }}"
spec:
  replicas: 1
  selector:                                                             # 新增加
    matchLabels:                                                   # 新增加
      app: gitlab-runner-ack-gitlab-runner             # 新增加

```
> 如何使用pvc
- 搭建nfs
[搭建nfs](https://www.jianshu.com/p/8dc6ba8d34b1)
- 创建pv

```
vim pv-nfs.conf
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv
  labels:
spec:
  nfs:
    path: /mnt/jamestest
    server: 192.168.0.252
  accessModes: ["ReadWriteMany","ReadWriteOnce"]
  capacity:
    storage: 100Gi


# 创建pv
kubectl apply -f pv-nfs.conf
```
- 修改ack-gitlab-runner中的pvc
```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  labels:
    app: {{ template "gitlab-runner.fullname" . }}
  name: gitlab-runner-cache
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  selector:
    matchLablel:
      app: nfs
```

- nfs类型pvc使用常见问题
  [常见问题](https://www.jianshu.com/p/175402cd5d3d)

> 打包部
- 打包部署
```
# helm 打包
helm package .
# 安装helm打包文件
helm install --namespace gitlab --name gitlab-runner *.tgz
# 查看安装是否成功
helm list
```
- helm 删除
```
# 删除已安装的包
helm del --purge gitlab-runner
```
## 检查
> 检查gitlab 管理页面是否出现该runner
> ![出现刚刚注册的runner](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/cicd/202201121334508.png)

# 参考
[gitlab-runner安装](https://help.aliyun.com/document_detail/106968.html)
- [非dockers安装gitlab-runner](https://www.jianshu.com/p/1014b0ec876d)