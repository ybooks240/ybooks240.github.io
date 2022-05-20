---
title: 居于kubeadm部署的etcd备份恢复
date: 2022-05-20 16:43:35
author:  
img: https://buleye.oss-cn-shenzhen.aliyuncs.com/images/etcd.png
top: true
hide: false
cover: true
coverImg: https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111645412.png
toc: true
mathjax: false
summary: k8s维护过程中，我们难免遇到etcd故障并且没有备份但是还有/var/lib/etcd/文件还存在的时候，我们如何解决此类问题呢，下面介绍居于kubeadmin部署的etcd备份恢复
categories: etcd
tags:
  - etcd
  - kubeadm
  - kubernetes
---

# 当ETCD没有备份故障时候恢复

在 `k8s`运行过程中， `etcd`集群异常的情况当时我们没有备份。我们该如何恢复ETCD呢。

| 端口 | 作用                             |
| ---- | -------------------------------- |
| 2379 | 提供 HTTP API 服务，供客户端交互 |
| 2380 | 和集群中其他节点通信             |

### 前提

```
# 该工具可从容器中拷贝出来
etcdctl 
# snapshot.db 文件来源，
cp /var/lib/etcd/member/snap/db /root/backup/snapshot.db 
```



## ansible 执行

### 配置

```
config.yaml

all:
  children:
    # etcd 节点
    etcd:
      hosts:
        IP1:
          ansible_ssh_user: "root"
          ansible_ssh_pass: "xxxxxx"
          ansible_ssh_port: 22
          hostname: "HOSTNAME1"  # ETCD名称
          ip: "<ETCD-IP1>"
        IP2:
          ansible_ssh_user: "root"
          ansible_ssh_pass: "xxxxxx"
          ansible_ssh_port: 22
          hostname: "HOSTNAME2"  # ETCD名称
          ip: "<ETCD-IP2>"
        IP3:
          ansible_ssh_user: "root"
          ansible_ssh_pass: "xxxxxx"
          ansible_ssh_port: 22
          hostname: "HOSTNAME3"  # ETCD名称
          ip: "<ETCD-IP3>"
```

## playbook

```
# 修改一下
etcd-restore.yaml

- hosts: etcd
  remote_user: root
  tasks:
  - name: stop cluster
    shell: mv /etc/kubernetes/manifests/{etcd.yaml,kube-apiserver.yaml} /tmp/

  - name: remove data
    shell:  rm -rf /var/lib/etcd/

  - name: restone etcd
  
    # 没有备份时候恢复方法
    shell: sleep 2&& ETCDCTL_API=3 etcdctl snapshot restore /root/backup/snapshot.db --skip-hash-check --name {{hostname}} --initial-cluster HOSTNAME1=https://ETCD-IP1:2380,HOSTNAME2=https://ETCD-IP2:2380,HOSTNAME3=https://ETCD-IP3:2380  --initial-cluster-token etcd --initial-advertise-peer-urls https://{{ip}}:2380 --data-dir=/var/lib/etcd
    
    # 有备份时候恢复方法
    #shell: sleep 2&& ETCDCTL_API=3 etcdctl snapshot restore /root/backup/etcd-snapshot-20220517.db --name {{hostname}} --initial-cluster HOSTNAME1=https://ETCD-IP1:2380,HOSTNAME2=https://ETCD-IP2:2380,HOSTNAME3=https://ETCD-IP3:2380  --initial-cluster-token etcd --initial-advertise-peer-urls https://{{ip}}:2380 --data-dir=/var/lib/etcd

  - name: start cluster
    shell: mv /tmp/{etcd.yaml,kube-apiserver.yaml} /etc/kubernetes/manifests/
```



## 执行恢复

```
ansible -i config.yaml etcd-restore.yaml
```

