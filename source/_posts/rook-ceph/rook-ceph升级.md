---
title: rook-ceph升级
date: 2022-01-07 05:40:35
author:  
img: https://buleye.oss-cn-shenzhen.aliyuncs.com/images/roo.png
top: true
hide: false
cover: true
coverImg: https://buleye.oss-cn-shenzhen.aliyuncs.com/images/roo.png
toc: true
summary: rook-ceph升级到v1.5.11以及配置存储网络分离以及设置metadevice设置实现网络优化
categories: rook-ceph
tags:
  - rook-ceph
  - kubernetes
  - csi
  - network
---



# rook-ceph升级

## 前言

由于`rook-ceph`在`v1.4.9`版本无法配置`osd`的日志盘，需要升级到`v1.5.11	`

## 注意事项

- 升级前存储必须要是正常状态
- 升级前需要做充分模拟以及演练
- 升级前做好对应的规划
- 出厂设置后变更配置文件或者其他则需要先修改再执行
- 升级过程中会伴随osd的多次重启

> 下面为官方升级建议

- **警告**：升级` Rook` 集群并非没有风险。可能存在会损害存储集群完整性和健康状况的意外问题或障碍，包括数据丢失。
- ` Rook operater`  更新和 `ceph` 版本更新的升级过程中，`Rook` 集群的存储可能会在短时间内不可用。
- 我们建议您在进行 `Rook `集群升级之前完整阅读本文档。

## rook v1.4.9升级到v1.5.11

### 设置环境变量

> 后续都在执行该环境变量终端下执行操作

```
export ROOK_OPERATOR_NAMESPACE="rook-ceph"
export ROOK_CLUSTER_NAMESPACE="rook-ceph"
```

### 升级前环境健康检查

> 若检查不通过，需要先解决对应的问题并检查通过方可继续升级

- 集群应该处于具有完整功能的健康状态

  1. `osd-prepare`为`Completed`状态，其余所有`pods`都为`Running`状态，如下图

  ```
  kubectl -n $ROOK_CLUSTER_NAMESPACE get pods
  ```

  ![image-20220111165757742](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/rook202201111657919.png)

  2. Ceph集群状态查询

  > - 集群健康：整体集群状态是`HEALTH_OK`，没有显示警告或错误状态消息。
  > - 监视器（mon）：所有监视器都包含在`quorum`列表中。
  > - 管理器（mgr）：Ceph 管理器处于`active`状态。
  > - OSD (osd)：所有 OSD 都是`up`和`in`。
  > - 归置组 (pgs)：所有 PG 都在`active+clean`状态中。

  ```
  TOOLS_POD=$(kubectl -n $ROOK_CLUSTER_NAMESPACE get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}')
  kubectl -n $ROOK_CLUSTER_NAMESPACE exec -it $TOOLS_POD -- ceph status
  ```

  ![image-20220111165925844](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111659035.png)

  3. 容器版本

  ```
  POD_NAME=$(kubectl -n $ROOK_CLUSTER_NAMESPACE get pod -o custom-columns=name:.metadata.name --no-headers | grep rook-ceph-mon-b)
  kubectl -n $ROOK_CLUSTER_NAMESPACE get pod ${POD_NAME} -o jsonpath='{.spec.containers[0].image}'
  ```
  
  ![image-20211222180142138](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111700581.png)
  
  ```
  kubectl -n $ROOK_OPERATOR_NAMESPACE get pod -o jsonpath='{range .items[*]}{.metadata.name}{"\n\t"}{.status.phase}{"\t\t"}{.spec.containers[0].image}{"\t"}{.spec.initContainers[0]}{"\n"}{end}' && \
  kubectl -n $ROOK_CLUSTER_NAMESPACE get pod -o jsonpath='{range .items[*]}{.metadata.name}{"\n\t"}{.status.phase}{"\t\t"}{.spec.containers[0].image}{"\t"}{.spec.initContainers[0].image}{"\n"}{end}'
  ```
  ![image-20211222180223673](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111701372.png)
  
  
  
  4. rook版本
  
  ```
  kubectl -n $ROOK_CLUSTER_NAMESPACE get deployments -o jsonpath='{range .items[*]}{.metadata.name}{"  \treq/upd/avl: "}{.spec.replicas}{"/"}{.status.updatedReplicas}{"/"}{.status.readyReplicas}{"  \trook-version="}{.metadata.labels.rook-version}{"\n"}{end}'
  
  kubectl -n $ROOK_CLUSTER_NAMESPACE get jobs -o jsonpath='{range .items[*]}{.metadata.name}{"  \tsucceeded: "}{.status.succeeded}{"      \trook-version="}{.metadata.labels.rook-version}{"\n"}{end}'
  ```
  
  ![image-20211222180303235](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111702159.png)
  
- 所有消耗 Rook 存储的 Pod 都应该被创建、运行并处于稳定状态

 > 晚上升级，保障数据写入以及pod的变动少

### 更新公共资源和CRD

```
kubectl apply -f common.yaml -f crds.yaml
```

> 无报错即可

![image-20211222180427314](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111702042.png)

### 更新 Ceph CSI 版本

> 由于ceph升级了，所以我们需要升级`csi`

#### 修改csi镜像配置

```
kubectl -n $ROOK_OPERATOR_NAMESPACE edit configmap rook-ceph-operator-config

data:
  CSI_FORCE_CEPHFS_KERNEL_CLIENT: "true"
  ROOK_CSI_ALLOW_UNSUPPORTED_VERSION: "false"
  ROOK_CSI_ENABLE_CEPHFS: "true"
  ROOK_CSI_ENABLE_GRPC_METRICS: "true"
  ROOK_CSI_ENABLE_RBD: "true"
  ROOK_OBC_WATCH_OPERATOR_NAMESPACE: "true"
  ROOK_CSI_CEPH_IMAGE: "cncp/csi/cephcsi:v3.2.2"
  ROOK_CSI_REGISTRAR_IMAGE: "cncp/csi/csi-node-driver-registrar:v2.0.1"
  ROOK_CSI_PROVISIONER_IMAGE: "cncp/csi/csi-provisioner:v2.0.4"
  ROOK_CSI_SNAPSHOTTER_IMAGE: "cncp/csi/csi-snapshotter:v3.0.2"
  ROOK_CSI_ATTACHER_IMAGE: "cncp/csi/csi-attacher:v3.0.2"
  ROOK_CSI_RESIZER_IMAGE: "cncp/csi/csi-resizer:v1.0.1"
```

![image-20211222182632326](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111702204.png)

#### 验证更新(Operator更新后验证)

```
kubectl --namespace rook-ceph get pod -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}' -l 'app in (csi-rbdplugin,csi-rbdplugin-provisioner,csi-cephfsplugin,csi-cephfsplugin-provisioner)' | sort | uniq

cncp/csi/cephcsi:v3.2.2
cncp/csi/csi-attacher:v3.0.2
cncp/csi/csi-node-driver-registrar:v2.0.1
cncp/csi/csi-provisioner:v2.0.4
cncp/csi/csi-resizer:v1.0.1
cncp/csi/csi-snapshotter:v3.0.2
```

![image-20211227152733044](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111702849.png)

### 更新Operator

```
kubectl -n $ROOK_OPERATOR_NAMESPACE set image deploy/rook-ceph-operator rook-ceph-operator=cncp/csi/operator-ceph:v1.5.11
```

![image-20211222181418290](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111702018.png)

### 等待升级完成

> 现在Ceph mons、mgrs、OSD被终止并被依次更新的版本替换。
>
> 集群可能会在 mons 更新时非常短暂地脱机，这是正常现象
>
> 可以通过下面命令进行插件，当查看命令结果`rook-version`都替换为v1.5.11

```
watch --exec kubectl -n $ROOK_CLUSTER_NAMESPACE get deployments -l rook_cluster=$ROOK_CLUSTER_NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}{"  \treq/upd/avl: "}{.spec.replicas}{"/"}{.status.updatedReplicas}{"/"}{.status.readyReplicas}{"  \trook-version="}{.metadata.labels.rook-version}{"\n"}{end}'
```

```
kubectl -n $ROOK_CLUSTER_NAMESPACE get deployment -l rook_cluster=$ROOK_CLUSTER_NAMESPACE -o jsonpath='{range .items[*]}{"rook-version="}{.metadata.labels.rook-version}{"\n"}{end}' | sort | uniq
集群未完成升级:
  rook-version=v1.4.9
  rook-version=v1.5.11
集群已经完成升级:
  rook-version=v1.5.11
```

- 升级中

![image-20211222181452066](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111702880.png)

![image-20211222181553745](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111704868.png)

- 升级完成

![image-20211222181831082](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111704868.png)

![image-20211222181852385](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111704869.png)

### 验证更新的集群

  1. `osd-prepare`为`Completed`状态，其余所有`pods`都为`Running`状态，如下图

  ```
  kubectl -n $ROOK_CLUSTER_NAMESPACE get pods
  ```

  ![image-20211222151959138](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111703437.png)

  2. Ceph集群状态查询

  > - 集群健康：整体集群状态是`HEALTH_OK`，没有显示警告或错误状态消息。
  > - 监视器（mon）：所有监视器都包含在`quorum`列表中。
  > - 管理器（mgr）：Ceph 管理器处于`active`状态。
  > - OSD (osd)：所有 OSD 都是`up`和`in`。
  > - 归置组 (pgs)：所有 PG 都在`active+clean`状态中。

  ```
  TOOLS_POD=$(kubectl -n $ROOK_CLUSTER_NAMESPACE get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}')
  kubectl -n $ROOK_CLUSTER_NAMESPACE exec -it $TOOLS_POD -- ceph status
  ```

![image-20211222182230713](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111703672.png)  ![image-20211222152246414](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111703271.png)

### ceph版本升级

#### 升级到 Ceph Octopus

1. 更新ceph守护进程daemons

```
NEW_CEPH_IMAGE='cncp/csi/ceph:v15.2.11'
CLUSTER_NAME="$ROOK_CLUSTER_NAMESPACE"  # change if your cluster name is not the Rook namespace
kubectl -n $ROOK_CLUSTER_NAMESPACE patch CephCluster $CLUSTER_NAME --type=merge -p "{\"spec\": {\"cephVersion\": {\"image\": \"$NEW_CEPH_IMAGE\"}}}"		
```

![image-20211222183139043](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111703944.png)

2. 等待守护进程pod更新完成

```
watch --exec kubectl -n $ROOK_CLUSTER_NAMESPACE get deployments -l rook_cluster=$ROOK_CLUSTER_NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}{"  \treq/upd/avl: "}{.spec.replicas}{"/"}{.status.updatedReplicas}{"/"}{.status.readyReplicas}{"  \tceph-version="}{.metadata.labels.ceph-version}{"\n"}{end}'
```

- 升级中

![image-20211222183600961](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111703307.png)

![image-20211222183829546](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111703730.png)

- 升级完成

![image-20211222183847543](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111703449.png)

#### 验证升级完成

```
# kubectl -n $ROOK_CLUSTER_NAMESPACE get deployment -l rook_cluster=$ROOK_CLUSTER_NAMESPACE -o jsonpath='{range .items[*]}{"ceph-version="}{.metadata.labels.ceph-version}{"\n"}{end}' | sort | uniq
集群未升级完成:
    ceph-version=14.2.7-0
    ceph-version=15.2.4-0
集群升级完成:
    ceph-version=15.2.4-0
```

- 升级中

![image-20211222183656335](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111703836.png)

- 升级完成

![image-20211222183906265](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111704141.png)

## 验证集群

- `osd-prepare`为`Completed`状态，其余所有`pods`都为`Running`状态，如下图

  ```
  kubectl -n $ROOK_CLUSTER_NAMESPACE get pods
  ```

  ![image-20211222184555423](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111704538.png)

- Ceph集群状态查询

  > - 集群健康：整体集群状态是`HEALTH_OK`，没有显示警告或错误状态消息。
  > - 监视器（mon）：所有监视器都包含在`quorum`列表中。
  > - 管理器（mgr）：Ceph 管理器处于`active`状态。
  > - OSD (osd)：所有 OSD 都是`up`和`in`。
  > - 归置组 (pgs)：所有 PG 都在`active+clean`状态中。

  ```
  TOOLS_POD=$(kubectl -n $ROOK_CLUSTER_NAMESPACE get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}')
  kubectl -n $ROOK_CLUSTER_NAMESPACE exec -it $TOOLS_POD -- ceph status
  ```

- 集群状态修复以及 集群状态查询

![image-20211222184632889](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111704049.png)

```
TOOLS_POD=$(kubectl -n $ROOK_CLUSTER_NAMESPACE get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}')
kubectl -n $ROOK_CLUSTER_NAMESPACE exec -it $TOOLS_POD -- ceph config set mon auth_allow_insecure_global_id_reclaim false

TOOLS_DEPLOY=$(kubectl -n $ROOK_CLUSTER_NAMESPACE get deploy -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}')
kubectl -n $ROOK_OPERATOR_NAMESPACE set image deploy/$TOOLS_DEPLOY $TOOLS_DEPLOY=cncp/csi/operator-ceph:v1.5.11

TOOLS_POD=$(kubectl -n $ROOK_CLUSTER_NAMESPACE get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}')
kubectl -n $ROOK_CLUSTER_NAMESPACE exec -it $TOOLS_POD -- ceph status
```

![image-20211222185544033](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111704869.png)

- rook版本

```
kubectl -n $ROOK_CLUSTER_NAMESPACE get deployment -l rook_cluster=$ROOK_CLUSTER_NAMESPACE -o jsonpath='{range .items[*]}{"rook-version="}{.metadata.labels.rook-version}{"\n"}{end}' | sort | uniq
```

- ceph版本

```
kubectl -n $ROOK_CLUSTER_NAMESPACE get deployment -l rook_cluster=$ROOK_CLUSTER_NAMESPACE -o jsonpath='{range .items[*]}{"ceph-version="}{.metadata.labels.ceph-version}{"\n"}{end}' | sort | uniq
```

![image-20211222185616485](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111704365.png)



# 配置存储网络网络分析

## 升级条件

- 升级前环境健康检查成功

## 配置解析

- osd-network.yaml

```
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: rook-cluster-nw
  namespace: rook-ceph
spec:
      config: '{
        "cniVersion": "0.3.0",
        "name": "cluster",
        "type": "macvlan",
        "master": "eth0",
        "mode": "bridge",
        "ipam": {
          "type": "whereabouts",
          "range": "172.17.29.100-172.17.29.200/24",     # 申请集群网络IP地址段或者范围
          "routes": [
          { "dst": "0.0.0.0/0" }
          ],
          "gateway": "172.17.29.247"                     # 申请集群网络IP网关
          }
        }'
```

- config-override.yaml 

```
apiVersion: v1
kind: ConfigMap
metadata:
  name: rook-config-override
  namespace: rook-ceph
data:
  config: |
    [global]
      cluster network = 172.17.29.0/24  # ceph 集群网络
```



## 配置网络插件

```
cd whereabouts
kustomize build |kubectl apply -f -
```

## 修改rook-ceph

```
kubectl -n rook-ceph scale deployment rook-ceph-operator --replicas=0

kubectl apply -f config-override.yaml -f osd-network.yaml

kubectl patch cephclusters.ceph.rook.io -n rook-ceph   rook-ceph --type merge --patch "$(cat rook-ceph-network-patch.yaml)"

kubectl -n rook-ceph scale deployment rook-ceph-operator --replicas=1
```

## 验证是否修改成功

```
kubectl -n $ROOK_CLUSTER_NAMESPACE exec -it $TOOLS_POD -- ceph osd dump
```

![image-20211224150055539](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111705616.png)

# 新增日志盘

## 配置日志盘条件

- 配置前环境健康检查通过
- 每块数据盘一块日志盘
- 日志盘的大小不小于数据盘的4%
- 配置数据盘时候需要下线对应数据盘进行初始化
- 下线数据盘需要考虑到当前集群容量是否可以满足当前机器移除后容量要求
- 下线数据盘需要考虑到当前集群容量是否可以满足当前机器移除后满足pool的容灾域要求（默认主机容灾）
- 日志盘需要时裸设备(`lsblk -f `)
- 逐步新增osd，切勿批量导致数据异常

## 集群检查

- 查看当前集群pool数量以及所有pool副本数

```
 kubectl -n $ROOK_CLUSTER_NAMESPACE exec -it $TOOLS_POD -- ceph osd pool ls
 
 # 判断osd分布情况是否满足容灾域要求
 kubectl -n $ROOK_CLUSTER_NAMESPACE exec -it $TOOLS_POD -- ceph osd pool get  bigstorage   size
 kubectl -n $ROOK_CLUSTER_NAMESPACE exec -it $TOOLS_POD -- ceph osd tree
```

## 日志盘配置

### 模拟配置日志盘

> 如，我需要将`test-rook-server2`上的`vdc`配置为`vdb`的日志盘

![image-20211224152949026](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111705586.png)

### osd对应磁盘

```
# 得到所有OSD的PODS
OSD_PODS=$(kubectl get pods --all-namespaces -l \
  app=rook-ceph-osd,rook_cluster=rook-ceph -o jsonpath='{.items[*].metadata.name}')

# OSD pods 找到对应设备
for pod in $(echo ${OSD_PODS})
do
 echo "Pod:  ${pod}"
 echo "Node: $(kubectl -n rook-ceph get pod ${pod} -o jsonpath='{.spec.nodeName}')"
 kubectl -n rook-ceph exec ${pod} -- sh -c '\
  for i in /var/lib/ceph/osd/ceph-*; do
    [ -f ${i}/ready ] || continue
    echo -ne "-$(basename ${i}) "
    echo $(lsblk -n -o NAME,SIZE ${i}/block 2> /dev/null || \
    findmnt -n -v -o SOURCE,SIZE -T ${i}) $(cat ${i}/type)
  done | sort -V
  echo'
done
```



> 根据输出我们可以判断得出`test-rook-server2`上的`vdb`为`osd2`

![image-20211224154347323](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111705797.png)

![image-20211224154252629](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111705626.png)

### 判断移除下线配置osd的影响

- 下线osd后集群容量是否可以承载当前集群的容量
- 下线osd后集群后满足pool的容灾域要求（默认主机容灾）

### 配置以及操作

- 设置operater

```
kubectl -n rook-ceph scale deployment rook-ceph-operator --replicas=0
```

![image-20211224161219205](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111705909.png)

- 新增日志盘

```
kubectl edit cephclusters.ceph.rook.io -n rook-ceph   rook-ceph

# 修改前
  storage:
    config:
      storeType: bluestore
    nodes:
    - devices:
      - name: vdb
      name: test-rook-server2
    - devices:
      - name: vdb
      name: test-rook-server3
    - devices:
      - name: vdb
      name: test-rook-server4
```

```
# 修改后
  storage:
    config:
      storeType: bluestore
    nodes:
    - devices:
      - config:
          metadataDevice: vdc
        name: vdb
      name: test-rook-server2
    - devices:
      - name: vdb
      name: test-rook-server3
    - devices:
      - name: vdb
      name: test-rook-server4
```

- 关闭osd

```
TOOLS_POD=$(kubectl -n $ROOK_CLUSTER_NAMESPACE get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}')
kubectl -n $ROOK_CLUSTER_NAMESPACE exec -it $TOOLS_POD --  bash 
ceph osd set noup
ceph osd down 2
ceph osd out 2
# 等待数据均衡完成
```

![image-20211224162646756](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111704916.png)

- 移除osd

```
ceph osd purge 2 --yes-i-really-mean-it
ceph osd unset noup
```

![image-20211224163133247](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111704153.png)

- 停止对应的`deploy`

```
kubectl delete deploy -n rook-ceph rook-ceph-osd-2
```

- ⚠️格式化磁盘（别删除错了）

```
lsblk -f 

sgdisk --zap-all /dev/vdb
dd if=/dev/zero of=/dev/vdb bs=1M count=100 oflag=direct,dsync

# 删除对应的链接
ll /dev/ce* |grep ceph--e95df59d--a57b--4 #（osd对应磁盘输出的名称）
lrwxrwxrwx 1 167 167 111 Dec 24 10:40 osd-block-52c2c0f8-dec5-44ad-98a7-b9737fb853cf -> /dev/mapper/ceph--e95df59d--a57b--4d76--9f93--d7f4a28652fe-osd--block--52c2c0f8--dec5--44ad--98a7--b9737fb853cf

find  /dev/ -name osd-block-52c2c0f8-dec5-44ad-98a7-b9737fb853cf
/dev/ceph-e95df59d-a57b-4d76-9f93-d7f4a28652fe/osd-block-52c2c0f8-dec5-44ad-98a7-b9737fb853cf

dmsetup ls
dmsetup  remove ceph--e95df59d--a57b--4d76--9f93--d7f4a28652fe-osd--block--52c2c0f8--dec5--44ad--98a7--b9737fb853cf

rm -rf /dev/ceph-e95df59d-a57b-4d76-9f93-d7f4a28652fe/osd-block-52c2c0f8-dec5-44ad-98a7-b9737fb853cf
lsblk
```

- 启动operator

```
kubectl -n rook-ceph scale deployment rook-ceph-operator --replicas=1
```

### 验证

- 在`test-rook-server2`上验证

```
lsblk -f 
```

![image-20211224163853917](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111704493.png)

- 在`osd2 pod`内验证

```
ceph-volume lvm list
```

![image-20211224164117775](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111704262.png)

- 查看集群状态

```
TOOLS_POD=$(kubectl -n $ROOK_CLUSTER_NAMESPACE get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}')
kubectl -n $ROOK_CLUSTER_NAMESPACE exec -it $TOOLS_POD -- ceph status
```

![image-20211224171326964](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201111704095.png)