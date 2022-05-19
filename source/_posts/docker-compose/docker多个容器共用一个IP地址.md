---
title: docker多个容器共用一个IP地址
date: 2022-01-11 16:43:35
author:  
img: 
top: true
hide: false
cover: true
coverImg: 
toc: true
mathjax: false
summary: 
categories: docker
tags:
  - docker
  - ip
---

# 如何使用docker-compose实现kubernetes pod共用IP功能

## 创建docker网络

```
docker network create -d macvlan --subnet=172.16.111.0/16 --gateway=172.16.0.254 -o parent=macvlan0 mac1
```

## 先创建一个容器

```
docker-compose]# docker run -it --name 11  --rm  --ip=172.16.111.150 --network mac1 busybox sh
```

## 再创建一个容器

```
docker run -it --name test22  --rm  --network=container:test11  busybox sh
```

## 对应执行`ip a`测试

```
# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
186: eth0@if2: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue
    link/ether 02:42:ac:10:6f:96 brd ff:ff:ff:ff:ff:ff
    inet 172.16.111.150/16 brd 172.16.255.255 scope global eth0
       valid_lft forever preferred_lft forever
/ #
```

