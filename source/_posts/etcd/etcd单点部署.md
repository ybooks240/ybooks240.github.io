---
title: etcd单点部署
date: 2022-01-12 11:40:35
author:  
img: https://buleye.oss-cn-shenzhen.aliyuncs.com/images/etcd.png
coverImg: https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111645412.png
toc: true
mathjax: false
summary: etcd传统环境下实现单独部署，以便熟悉etcd相关操作以及理论实践。本文主要提供etcd单节点部署
categories: etcd
tags:
  - etcd
---

# etcd单节点部署

## 下载安装包

```
mkdir /opt/etcd/bin /var/lib/etcd /opt/etcd/config/ -p
wget -O /opt/etcd/etcd-v3.1.5-linux-amd64.tar.gz  https://github.com/coreos/etcd/releases/download/v3.1.5/etcd-v3.1.5-linux-amd64.tar.gz
cd /opt/etcd/ && tar xzvf etcd-v3.1.5-linux-amd64.tar.gz
mv etcd* /bin
```

## 配置

- 配置etcd配置文件

```
cat <<EOF | sudo tee /opt/etcd/config/etcd.conf
#节点名称
ETCD_NAME=$(hostname -s)
#数据存放位置
ETCD_DATA_DIR=/var/lib/etcd
EOF
```
- 配置etcd启动脚本

```
cat <<EOF | sudo tee /etc/systemd/system/etcd.service

[Unit]
Description=Etcd Server
Documentation=https://github.com/coreos/etcd
After=network.target

[Service]
User=root
Type=notify
EnvironmentFile=-/opt/etcd/config/etcd.conf
ExecStart=/opt/etcd/bin/etcd
Restart=on-failure
RestartSec=10s
LimitNOFILE=40000

[Install]
WantedBy=multi-user.target
EOF
```

- 配置环境变量

```
echo PATH=$PATH:/opt/etcd/bin/ >>~/.bash_profile
source ~/.bash_profile
```
- 启动etcd

```
systemctl daemon-reload && systemctl enable etcd && systemctl start etcd
```
## 测试

```
etcd --version
```

## 命令使用

```
--debug 输出CURL命令，显示执行命令的时候发起的请求
--no-sync 发出请求之前不同步集群信息
--output, -o 'simple' 输出内容的格式(simple 为原始信息，json 为进行json格式解码，易读性好一些)
--peers, -C 指定集群中的同伴信息，用逗号隔开(默认为: "127.0.0.1:4001")
--cert-file HTTPS下客户端使用的SSL证书文件
--key-file HTTPS下客户端使用的SSL密钥文件
--ca-file 服务端使用HTTPS时，使用CA文件进行验证
--help, -h 显示帮助命令信息
--version, -v 打印版本信息
```