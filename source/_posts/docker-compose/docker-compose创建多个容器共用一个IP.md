---

title: docker-compose多个容器共用一个IP地址
date: 2022-05-20 16:43:35
author:  
img: 
top: true
hide: false
cover: true
coverImg: 
toc: true
mathjax: false
summary: 
categories: docker-compose
tags:
  - docker-compose
  - ip
---

# 如何使用docker-compose实现kubernetes pod共用IP功能

## 创建docker网络

```
docker network create -d macvlan --subnet=172.16.111.0/16 --gateway=172.16.0.254 -o parent=macvlan0 mac1
```

## 配置docker-compose

```
version: '2'
services:
  test1:
    image: busybox
    command: sh -c "sleep 36000000"
    networks:
      mac1:
        ipv4_address: 172.16.111.152
  test2:
    image: busybox
    command: sh -c "sleep 36000000"
    network_mode: "service:test1"
    depends_on:
      - test1
networks:
  mac1:
    external: true
```

## 测试

```
# docker-compose exec test1 ifconfig eth0
eth0      Link encap:Ethernet  HWaddr 02:42:AC:10:6F:98
          inet addr:172.16.111.152  Bcast:172.16.255.255  Mask:255.255.0.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:307584 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0
          RX bytes:20095408 (19.1 MiB)  TX bytes:0 (0.0 B)

# docker-compose exec test2 ifconfig eth0
eth0      Link encap:Ethernet  HWaddr 02:42:AC:10:6F:98
          inet addr:172.16.111.152  Bcast:172.16.255.255  Mask:255.255.0.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:307881 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0
          RX bytes:20115460 (19.1 MiB)  TX bytes:0 (0.0 B)
```



