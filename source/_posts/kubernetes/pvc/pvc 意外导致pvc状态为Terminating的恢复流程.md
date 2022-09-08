---
title: 意外导致pvc状态为Terminating的恢复流程
date: 2022-09-07 12:40:35
author: james.liu
top:false
hide: false
toc: true
mathjax: false
summary: 意外导致pvc状态为Terminating的恢复流程
categories: Markdown
tags:
  - kubernetes
  - pvc
---

## 模拟`pvc`故障问题

#### 查看正常状态下`pv`以及`pvc`

  ![image-20210414150001610](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202209081501275.png)

  ```
  kubectl get pvc  -n ns-xmrkcipnc   -l app.kubernetes.io/part-of=redis-failover
  kubectl get pv|grep ns-xmrkcipnc|grep redis
  ```

#### 模拟`pvc`故障意外

  ![image-20210414150059508](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202209081501917.png)

  ```
  kubectl delete  pvc  -n ns-xmrkcipnc   -l app.kubernetes.io/part-of=redis-failover
  kubectl get pvc  -n ns-xmrkcipnc   -l app.kubernetes.io/part-of=redis-failover
  ```

  

  ## `pvc`故障恢复流程

> ⚠️有条件下请备份再操作，注意步骤

#### 前言

- **申请并等待可以操作的窗口期，否则操作期间会导致业务异常以及部分数据丢失**

- 注意事项
  - 下面实施操作命令会根据条件有所变化，务必理解对应逻辑再操作避免出现数据丢失问题

#### 实施操作

##### **修改`pv`状态（批量修改）**

  ```
  # 修改pv状态（注意查询的实体比对）
  for pv in `kubectl get pvc  -n ns-xmrkcipnc   -l app.kubernetes.io/part-of=redis-failover|grep Terminating|awk '{print $3}'`;do kubectl patch pv $pv -p '{"spec":{"claimRef":{"uid":""}}}';done
  ```

  ![image-20210414152401402](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202209081501435.png)



##### 修改`pv`状态（单个修改）

  ```
  kubectl edit pv pvc-342ccb9b-bc9f-4169-ac68-eca4a4193550
  spec:
    accessModes:
    - ReadWriteOnce
    capacity:
      storage: 819Mi
    claimRef:
      apiVersion: v1
      kind: PersistentVolumeClaim
      name: data-redis-4x5yzix0a-2
      namespace: ns-xmrkcipnc
      resourceVersion: "16118531"
      uid: ed581331-c029-4bd5-a62d-c41913b06bc8   # 删除改行
  ```

![image-20210414160001072](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202209081501611.png)

##### 查看`pv`状态

  ```
  # 查看pv状态
  kubectl get pv `kubectl get pvc  -n ns-xmrkcipnc   -l app.kubernetes.io/part-of=redis-failover|grep Terminating|awk '{print $3}'`
  ```

  ![image-20210414152220365](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202209081501286.png)

##### Pod停止

##### 略  

##### 系统查看`redis`组件状态`0/0`为停止成功

  ![image-20210414152828647](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202209081501925.png)

  ```
  # kubectl get sts -n ns-xmrkcipnc redis-4x5yzix0a
  NAME              READY   AGE
  redis-4x5yzix0a   0/0     46m
  ```

##### pod启动

略

![image-20210414152845823](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202209081502302.png)

```
### 查看组件恢复是否正常
kubectl get sts -n ns-xmrkcipnc redis-4x5yzix0a
```

- 恢复结果检查

![image-20210414152950472](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202209081502715.png)



### 检查恢复是否成功，`pv`以及`pvc`状态是否正常

#### 查看`pod`状态

  ```
  # kubectl get pod  -n ns-xmrkcipnc   -l app.kubernetes.io/part-of=redis-failover
  ```

  ![image-20210414153201020](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202209081502231.png)

#### 查看`pvc`状态

  ```
  # kubectl get pvc  -n ns-xmrkcipnc   -l app.kubernetes.io/part-of=redis-failover
  ```

  ![image-20210414153242987](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202209081502803.png)

#### 查看`pv`状态

  ```
  kubectl get pv|grep ns-xmrkcipnc|grep redis
  ```

  ![image-20210414153325160](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202209081502052.png)
