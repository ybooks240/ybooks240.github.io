---
title: rook-ceph osd 内存限制
date: 2022-01-11 15:40:35
author:  
img: https://buleye.oss-cn-shenzhen.aliyuncs.com/images/rook-ceph/osd-memory-xx1.png
coverImg: https://buleye.oss-cn-shenzhen.aliyuncs.com/images/rook-ceph/osd-memory-xx1.png
toc: true
summary: rook-ceph默认情况下，当osd均衡或者大量的数据读情况下，rook-ceph-osd在没有限制，此时会出现内存无限增长，当内存无法满足时候进程直接OOM从而导致集群大量异常，从而再次均衡，导致雪崩
categories: rook-ceph
tags:
  - rook-ceph
  - 优化
---

## rook-ceph内存限制

> 在osd均衡以及大量的数据读情况下，rook-ceph-osd在没有限制情况下会出现内存无限增长

### 模拟内存增长

> 数据均衡

- 关闭osd，模拟osd异常，数据进行均衡

```
ceph osd set noup
ceph osd down <id>
# 模拟完成后关闭
ceph osd unset noup
```

- 启动数据均衡

```
ceph  balancer on
ceph  balancer status
# 模拟完成后关闭
ceph  balancer off
```

> 压测数据读

- 压测模拟

```
rados bench -p bigstorage 2000 write -t 60 --run-name  client1 no-cleanup
rados bench -p bigstorage 2000 rand --run-name client1
# 模拟完成后删除压测数据
rados -p bigstorage cleanup --prefix benchmark_data
```

### 内存数据分析

```
ceph tell osd.<id> heap start_profiler
ceph tell osd.<id> heap dump
# 关闭内存分析
ceph tell osd.<id> heap stop_profiler
```

![image-20211215104016153](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111855304.png)

### 内存限制

> 官方推荐osd内存占用最小推荐为`3GB`,每增涨1TB则新增`1GB`内存

```
# 命令行实现
ceph config set osd.<id> osd_memory_target 5368709120
# for i in `seq 0 <NUM>`;do ceph config set osd.$i osd_memory_target 5368709120;done
```

### 查询

```
# 观察内存变化
kubectl  top pod -A -l  app=rook-ceph-osd --sort-by='memory'
# 查看设置是否成功
ceph config get osd.<id> osd_memory_target
# 查看配置
ceph config dump
```

### 部分截图

> 如下图，`osd2`以及`osd6`设置了内存限制，此时观察发现`osd2`以及`osd6`限制为`5GB`以内

![image-20211215110201700](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111855375.png)

> 如何确保内存限制成功呢

使用实验对照组进行测试，将`osd.2`或者`osd.6`的限制进行删除，再执行《模拟内存增长》，⚠️多次测试

```
ceph config rm osd.<id> osd_memory_target
```

![image-20211215111332077](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111855612.png)