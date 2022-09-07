---
title: macvlan
date: 2022-01-12 11:40:35
author:  
img: https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251234373.jpg
top: true
hide: false
cover: true
toc: true
mathjax: false
summary: mtacvlan
categories: cni
tags:
- cni
- macvlan
---



## 什么是macvlan

macvlan 是将一块以太网卡虚拟成多块以太网卡的一种技术方案。一块以太网卡需要有一个MAC地址，以往，我们使用一块以太网卡也可以配置多个IP地址类似ethx:y，但是他们的MAC地址是一样的。这里本质上还是一块网卡，在二层数据处理上有很多限制（数据链路层物理寻址需要mac地址），所以macvlan技术就出来了。

macvlan有几种模式，如下

- VEPA macvlan接口出来的流程都发送到父接口，由于生成树协议限制两个子接口之间通讯会给阻塞，需要配置Hairpin支持，也就是源和目的地址都是本地 Macvlan 接口地址的流量发回给相应的接口，所以需要交换机设备支持，无法配置交换机情况下也可以使用网桥代替交换机，将网卡设备放置到网桥中，再让网桥启动hairpin，如`brctl hairpin br0 eth1 on`

![preview](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251234221.png)

![在这里插入图片描述](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251234709.png)

- Private     和VEPA模式类似，但其完全阻止共享同一父接口的 Macvlan 虚拟网卡之间的通讯，即使配置了 `Hairpin` 让从父接口发出的流量返回到宿主机，相应的通讯流量依然被丢弃。

  

![img](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251234291.jpg)

- Bridge    和linux上网桥类似，子网卡之间数据可以相互通讯。但是不需要mac地址学习，也不需要STP（生成树协议），效率比网桥高，但是父接口down会导致子接口全部down，从而无法通讯。（所以生产环境使用bond网卡作为父接口）

  ![img](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251234373.jpg)

  ![在这里插入图片描述](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251234027.png)

- Passthru    每个父接口只能和一个 Macvlan 虚拟网卡接口进行捆绑，并且 Macvlan 虚拟网卡接口继承父接口的 MAC 地址。此种模式的优点是虚拟机和容器可以更改 MAC 地址和其它一些接口参数。

![img](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251234335.jpg)

我们使用的是Bridge模式，

缺点：

- 父网卡和子网卡无法通讯（看下图）
- 由于802.11无法识别一块网卡多个MAC地址，则无线环境下无法通讯
- 物理网卡对MAC地址数量过大导致性能影响问题
- 交换机面对同一网卡内MAC地址数量过大影响性能问题
- 交换机MAC地址限制问题

![img](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251234017.png)

物理网卡也就相当于一个交换机，记录着对应的虚拟网卡和 MAC 地址，当物理网卡收到数据包后，会根据目的 MAC 地址判断这个包属于哪一个虚拟网卡。这也就意味着，只要是从 Macvlan 子接口发来的数据包（或者是发往 Macvlan 子接口的数据包），物理网卡只接收数据包，不处理数据包，所以这就引出了一个问题：本机 Macvlan 网卡上面的 IP 无法和物理网卡上面的 IP 通信！

![img](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251234842.jpg)

### macvlan和bridge区别

> Macvlan

- 仅仅需要为虚拟机或容器提供访问外部物理网络的连接。
- Macvlan 占用较少的 CPU，同时提供较高的吞吐量。
- 宿主机无法和 VM 或容器直接进行通讯。

> Bridge

- 需要应用高级流量控制，FDB的维护。



> 为什么bond可以作为父接口

### 使用macvlan

- 命令

```
ip link add link eth0 name macvlan1 type macvlan mode bridge
```

- 网卡macvlan配置

```
vim /etc/sysconfig/network-scripts/ifcfg-eth0
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
#DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=no
NAME=eth0
DEVICE=eth0
ONBOOT=yes


cat /etc/sysconfig/network
# Created by anaconda
if ! ip l show macvlan1 &>/dev/null; then
 ip l add link eth0 name macvlan1 type macvlan mode bridge
 ifconfig macvlan1 172.16.123.200/24 
fi
if ! ip r | grep default &>/dev/null;then
 ip r add default via 172.16.123.254 dev macvlan1
fi
```

- docker

```
# --subnet= "" macvlan设置⽹络
docker network create -d macvlan --subnet=172.16.123.0/24 --gateway=172.16.123.254 -o parent=eth1 mac1

docker run -itd --name c1 --ip=172.16.123.200 --network mac1 busybox
```

- 网络插件cni

```
# /opt/cni/bin/macvlan
# cat >/test-cni/macvlan-demo.conf<<EOF
{
    "cniVersion": "0.3.0",
    "type": "macvlan",           # macvlan
    "master": "eth0",            # 父接口
    "mode": "bridge",            # 模式
    "ipam": {
          "type": "host-local",
          "subnet": "172.16.0.0/16",
          "rangeStart": "172.16.123.101",
          "rangeEnd": "172.16.123.200",
          "routes": [
            { "dst": "0.0.0.0/0" }
          ],
          "gateway": "172.16.0.254"
     }
}
EOF
cd /opt/cni/bin
ip netns add macvlan-demo
ip netns list
CNI_COMMAND=ADD CNI_CONTAINERID=macvlan-demo CNI_NETNS=/var/run/netns/macvlan-demo CNI_IFNAME=eth0 CNI_PATH=/opt/cni/bin ./macvlan </test-cni/macvlan-demo.conf
```

### kubernetes如何使用multus创建macvlan网卡

- 安装multus

```
- 修改配置文件cncp.yaml
- make gen,make cncp

#安装010-cni插件
#安装040-cert
```

- 配置

```
cat <<EOF | kubectl create -f -
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: macvlan0
  namespace: kube-system
spec:
  config: '{
    "cniVersion": "0.3.0",
    "type": "macvlan",
    "master": "eth0",
    "mode": "bridge",
    "ipam": {
          "type": "host-local",
          "subnet": "172.16.0.0/16",
          "rangeStart": "172.16.123.101",
          "rangeEnd": "172.16.123.200",
          "routes": [
            { "dst": "0.0.0.0/0" }
          ],
          "gateway": "172.16.0.254"
     }
  }'
EOF


# 创建pod
cat <<EOF | kubectl create -f -
apiVersion: v1
kind: Pod
metadata:
  name: macvlan-demo
  annotations:
    v1.multus-cni.io/default-network: '[{"name":"macvlan0","namespace":"kube-system","ips":["172.16.123.108"]}]'   # 使用上述配置去配置默认网卡指定IP
spec:
  containers:
  - name: macvlan-demo
    image: cncp/utils/network-multitool:latest
EOF
```

