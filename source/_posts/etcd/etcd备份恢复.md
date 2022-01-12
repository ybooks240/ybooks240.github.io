---
title: 居于kubeadm部署的etcd备份恢复
date: 2022-01-11 16:43:35
author:  
img: https://buleye.oss-cn-shenzhen.aliyuncs.com/images/etcd.png
top: true
hide: false
cover: true
coverImg: https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111645412.png
toc: true
mathjax: false
summary: k8s维护过程中，我们难免遇到etcd故障或者需要备份恢复的时候，我们如何解决此类问题呢，下面介绍居于kubeadmin部署的etcd备份恢复
categories: etcd
tags:
  - etcd
  - kubeadm
  - kubernetes
---

# 居于`kubeadm`部署的etcd备份恢复

## 前言

在`k8s`运行过程中难免会遇到`etcd`集群异常的情况。我们该如何做到备份以及恢复。


## ETCD 备份

```
ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt  --key=/etc/kubernetes/pki/etcd/server.key --endpoints=https://<IP>:2379 snapshot save ./etcd-snapshot-`date +%Y%m%d`.db
```

## ETCD恢复

- 将备份文件传到所有etcd节点中

  使用`scp`拷贝到各个机器·

- 逐台停止`kube-apiserver`以及所有`etcd`服务

  ```shell
  mv /etc/kubernetes/manifests/{etcd.yaml,kube-apiserver.yaml} /tmp/
  ```

- 备份etcd数据目录并留空

  ```
  rm -rf /var/lib/etcd
  ```

- 逐台执行命令去恢复

  ```
  ETCDCTL_API=3 etcdctl snapshot restore ./etcd-snapshot-20211009.db \
    --name <HOSTNAME> \
  #   --initial-cluster "<HOSTNAME>=https://<IP>:2380" \ 单节点则写单个
    --initial-cluster "<HOSTNAME>=https://<IP>:2380,<HOSTNAME>=https://<IP>:2380,<HOSTNAME>=https://<IP>:2380" \
    --initial-cluster-token etcd-cluster \
    --initial-advertise-peer-urls https://192.168.1.36:2380 \
    --data-dir=/var/lib/etcd/
  ```

- 逐台启动启动`api-service`以及`etcd`服务

  ```
   mv /tmp/{etcd.yaml,kube-apiserver.yaml} /etc/kubernetes/manifests/
  ```

- 检查etcd集群状态

  ```
  ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt  --key=/etc/kubernetes/pki/etcd/server.key --endpoints=https://172.16.111.130:2379   member list
  ```

- kubelet检查

  ```
  kubectl get node
  kubectl get cs
  ```

  
## ETCD操作

- 查询健康状态

  ```
  ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key --endpoints=https://172.16.111.130:2379 endpoint health
  ```

- 查询所有key

  ```
  ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt  --key=/etc/kubernetes/pki/etcd/server.key --endpoints=https://172.16.111.130:2379 get / --prefix --keys-only
  ```

- 查看成员

  ```
  ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt  --key=/etc/kubernetes/pki/etcd/server.key --endpoints=https://172.16.111.130:2379   member list
  ```