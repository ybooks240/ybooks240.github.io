---
title: 释放 Kubernetes 故障节点上的 RBD 卷
date: 2022-09-07 11:40:35
author: james.liu
top: false
hide: false
toc: true
mathjax: false
summary: 释放 Kubernetes 故障节点上的 RBD 卷
categories: Markdown
tags:
  - kubernetes
  - pvc
  - rook-ceph
---

# 释放 Kubernetes 故障节点上的 RBD 卷

## 现象

- sts由于唯一性导致无法直接漂移，出现`Terminating`，以及长期`init`状态的`pod`

![image-20220902152404094](./images/%E8%8A%82%E7%82%B9%E5%BC%82%E5%B8%B8%E9%97%AE%E9%A2%98%E8%A7%A3%E5%86%B3%E5%8A%9E%E6%B3%95/image-20220902152404094.png)

- 我们也无法直接删除该`pod`,强制删除后依然无法完成启动。

![image-20220902152213882](./images/%E8%8A%82%E7%82%B9%E5%BC%82%E5%B8%B8%E9%97%AE%E9%A2%98%E8%A7%A3%E5%86%B3%E5%8A%9E%E6%B3%95/image-20220902152213882.png)

- 原因

`kubectl describe pod`查看对应的失败原因情况下，由于存储后端为ceph-rbd，而ceph-rbd的pvc为支持RWO。

- `Terminating`状态的pod的原因，无法完成unmap操作，也就是unattch操作，此时由于sts的唯一性，无法完成pod漂移操作，由于需要等待解绑操作的完成，则由于锁无法完成删除操作。
- 长期`init`状态，由于存储后端为ceph-rbd，而ceph-rbd的pvc为支持RWO，在不同节点上无法完成attach操作。

如果是RWO则需要解决pvc无法挂载问题如下：

![image-20220902152032425](./images/%E8%8A%82%E7%82%B9%E5%BC%82%E5%B8%B8%E9%97%AE%E9%A2%98%E8%A7%A3%E5%86%B3%E5%8A%9E%E6%B3%95/image-20220902152032425.png)

## 解决办法

###  故障节点登陆：

- 停止并删除其中的容器 docker stop xxx
- 卸载该卷 umount
- 解除绑定操作 unmap /dev/rbdx

### 故障节点不可登陆：

- 找到对应的images信息  kubectl get pv PVNAME -o yaml|awk '/imageName|pool/'

![image-20220902153359488](./images/%E8%8A%82%E7%82%B9%E5%BC%82%E5%B8%B8%E9%97%AE%E9%A2%98%E8%A7%A3%E5%86%B3%E5%8A%9E%E6%B3%95/image-20220902153359488.png)

- 查看该images信息状态  rbd status -p bigstorage csi-vol-24298ba1-2130-11ed-b43d-0e005bd3f3f6

- 将该关联拉黑. ceph osd blacklist add 172.199.1.0:0/286978028

![image-20220902153459422](./images/%E8%8A%82%E7%82%B9%E5%BC%82%E5%B8%B8%E9%97%AE%E9%A2%98%E8%A7%A3%E5%86%B3%E5%8A%9E%E6%B3%95/image-20220902153459422.png)

## 参考

[参考1](https://blog.51cto.com/wendashuai/2493435)

[参考2](https://blog.fleeto.us/post/unbound-rbd-from-a-notready-node/)