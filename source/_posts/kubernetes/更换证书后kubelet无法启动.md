---
title: 更换证书后kubelet无法启动
date: 2022-09-08 12:40:35
author: james.liu
top: false
hide: false
toc: true
mathjax: false
summary: 更换证书后kubelet无法启动
categories: kubernetes
tags:
  - kubernetes
  - cert
---

## 现象

![现象](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202209081648156.png)

![现象2](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202209081649830.png)

## 原因分析



这种问题都是出现在第一台初始化的master节点，因为当集群安装时候集群没有起来则第一台机器使用的是kubelet的证书，而kubeadm更新证书时候没有更新kubelet证书导致。

## 解决办法

```
cp /etc/kubernetes/admin.conf /etc/kubernetes/kubelet.conf
cp /etc/kubernetes/kubelet.conf ~/.kube/config
```





