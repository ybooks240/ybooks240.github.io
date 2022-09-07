---
title: rook-ceph下线osd
date: 2022-01-07 05:40:35
author:  
img: https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111748228.png
top: true
hide: false
cover: true
coverImg: https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111748228.png
toc: true
mathjax: false
summary: rook-ceph在使用过程中难免会遇到磁盘异常的情况，我们如何安全下线磁盘进行维护。
categories: rook-ceph
tags:
  - rook-ceph
  - csi
  - kubernetes 
---

## 前言

现在有需求需要停止`172-17-27-77`上的`sda`也就是`osd0`

![image-20211203131608704](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111718099.png)

![image-20211203131633866](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111718595.png)

## ## 如何查找对应的osd和磁盘关系



## 解决办法



- 先把operator设置为0

  ```
  kubectl -n rook-ceph scale deployment rook-ceph-operator --replicas=0
  ```

  ![image-20211203131753375](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111718630.png)

- 修改配置，将需要移除的盘移除：

  ```
  kubectl edit cephclusters.ceph.rook.io -n rook-ceph   rook-ceph
  ```
  
  > 删除对应的对应的盘，如只有一款盘则直接删除主机则圈起来部分
  >
  > ⚠️如果是该主机下多块盘则删除对应的盘即可，则sda
  >
  > 当前截图情况删除圈起来部分
  
  ![image-20211203131934027](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111718816.png)
  
- 登陆到`toolbox pod`内手动移除对应的`osd`：
  
  ```
  kubectl exec -it  -n rook-ceph      rook-ceph-tools-769bdf4bdd-hdx6r bash 
  ceph osd set noup
  ceph osd down 0
  ceph osd out 0 
  # 等待数据均衡完成
  ```
  
  ![image-20211203132613145](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111718053.png)
  
  ![image-20211203132635520](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111718386.png)
  
  ![image-20211203132658631](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111719261.png)

# 均衡数据完成后移除对应的osd

```
ceph osd purge 0 --yes-i-really-mean-it
ceph auth del osd.0
```

![image-20211203165153751](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111719577.png)

# 如果该主机只有一块盘则对应移除该主机

> ⚠️可以通过`ceph osd tree`确定该主机是否为一块盘

```
ceph osd crush remove 172-17-27-77
```

![image-20211203165123961](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111719009.png)

# 检查ceph状态以及osd状态

```
ceph -s
ceph osd tree
```

# 移除pod，和判断删除对应的job

```
kubectl delete deploy -n rook-ceph rook-ceph-osd-0
```

## 恢复配置

```
ceph osd unset noup
```

## 恢复rook的operator

```
kubectl -n rook-ceph scale deployment rook-ceph-operator --replicas=1
```

## 检查对应osd的pod是否启动

```
kubectl get pod  -n rook-ceph      -l  app=rook-ceph-osd -o wide
```

![image-20211203171055644](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111719475.png)

