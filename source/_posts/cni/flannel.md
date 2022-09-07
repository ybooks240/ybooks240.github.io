---
title: flannel
date: 2022-01-12 11:40:35
author:  
img: https://buleye.oss-cn-shenzhen.aliyuncs.com/images/cni/flannel/image-20220112162558328.png
top: true
hide: false
cover: true
toc: true
mathjax: false
summary: flannel之vxlan
categories: cni
tags:

- cni
- flannel
---



![image-20220112162558328](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/cni/flannel/image-20220112162558328.png)

## 网络基础

### IP信息

IP （Internet Protocol Address）是一种在Internet上的给主机编址的方式，也称为网际协议地址。IP地址是IP协议提供的一种统一的地址格式，它为互联网上的每一个网络和每一台主机分配一个逻辑地址。

### 交换机和网桥

交换机：交换机主要工作在 OSI 参考模型的第二层，也就是**数据链路层**。能够同时连接许多对端口，使得每一对相互通信的主机都能够像独占通信媒体那样，进行无冲突地传输数据。和集线器不同的是，集线器采取的是广播的方式，而交换机的数据传输是根据 MAC 地址表进行的，只有当 MAC 地址表中找不到地址的时候才进行广播处理。

网桥：网桥工作在 OSI 参考模型的第二层，也就是**数据链路层**。将相似的网络连接起来，并对网络的数据流通进行管理。网桥只有 2 个输入或者输出的端口，而交换机则有多个。而网桥里的 MAC 地址表则是一个端口对应多个地址，而在交换机里则是一个端口对应一个 MAC 地址。

### 路由器

路由器工作在 OSI 参考模型的第三层，也就是**网络层**。主要对不同的网络中的数据进行存储、分组转发处理，使得数据从一个子网传输到另外一个子网里去，把数据包按照选定的路由算法传送到指定的位置。

### iptables

![img](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251229989.svg)

>  5 个内置的链(chain)

- PREROUTING：接收的数据包刚进来，还没有经过路由选择，即还不知道数据包是要发给本机还是其它机器。这时会触发该 chain 上的规则。
- INPUT：已经经过路由选择，并且该数据包的目的 IP 是本机，进入本地数据包处理流程。此时会触发该 chain 上的规则。
- FORWARD：已经经过路由选择，但该数据包的目的 IP 不是本机，而是其它机器，进入 forward 流程。此时会触发该 chain 上的规则。
- OUTPUT：本地程序要发出去的数据包刚到 IP 层，还没进行路由选择。此时会触发该 chain 上的规则。
- POSTROUTING：本地程序发出去的数据包，或者转发(forward)的数据包已经经过了路由选择，即将交由下层发送出去。此时会触发该 chain 上的规则。

> 表

- filter：一般的过滤功能
- nat:用于nat功能（端口映射，地址映射等）
- mangle:用于对特定数据包的修改
- raw:有限级最高，设置raw时一般是为了不再让iptables做数据包的链接跟踪处理，提高性能

表的处理优先级：raw>mangle>nat>filter

> Targets 就是找到匹配的数据包之后怎么办，常见的有下面几种：

- DROP：直接将数据包丢弃，不再进行后续的处理
- RETURN： 跳出当前 chain，该 chain 里后续的 rule 不再执行
- QUEUE： 将数据包放入用户空间的队列，供用户空间的程序处理
- ACCEPT： 同意数据包通过，继续执行后续的 rule
- 其他： 跳转到其它用户自定义的 chain 继续执行

![iptables](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251229997.png)

### veth pair and netns

veth-pair 就是一对的虚拟设备接口，它都是成对出现的。一端连着协议栈，一端彼此相连着，犹如一根网线。

Network Namespace （以下简称netns）是Linux内核提供的一项实现网络隔离的功能，它能隔离多个不同的网络空间，并且各自拥有独立的网络协议栈，这其中便包括了网络接口（网卡），路由表，iptables规则等。docker的网络隔离用的就是netns。

#### 模拟一下docker实现通讯（视频演示过程中无法对外通讯由于网卡地址不是eth0而是macvlan0导致）

```
# 新建network namespace，类似新建一台没有网络的机器
[root@test-rook-server2 ~]# ip netns add demo
# 新建veth pair，类似新建一根网线
[root@test-rook-server2 ~]# ip link add veth-1 type veth peer name veth-2
# 将veth pair放到demo netns中并配置IP启动，类似将网线一端插上并启动
[root@test-rook-server2 ~]# ip link set dev veth-2 netns demo
[root@test-rook-server2 ~]# ip link set dev veth-1 up
[root@test-rook-server2 ~]# ip netns exec demo ip link set dev veth-2 up
[root@test-rook-server2 ~]# ip netns exec demo ip addr add 10.0.0.2/24 dev veth-2

# 创建网桥并启动，类似创建一台交换机，类似docker0
# 网桥和交换机不同的是，网桥可配置IP，交换机没有IP
[root@test-rook-server2 ~]# ip link add demo-docker0 type bridge
[root@test-rook-server2 ~]# ip link set dev demo-docker0 up
[root@test-rook-server2 ~]# ip addr add 10.0.0.1/24 dev demo-docker0

# 将veth pair和网桥建立联系，类似将网线一端插入到交换机中
# 原本由veth-2出来的数据会给veth-1处理，但是由于将veth-1和网桥建立了联系，veth-1降级，会将数据包给到demo-docker0进行处理
[root@test-rook-server2 ~]# ip link set dev veth-1 master demo-docker0

# 设置路由
[root@test-rook-server2 ~]# ip netns exec demo ip route add default via 10.0.0.1 dev veth-2

# 本地机器启动路由转发功能，并设置nat，类似办公室网络
[root@test-rook-server2 ~]# sysctl -w net.ipv4.ip_forward=1
net.ipv4.ip_forward = 1
[root@test-rook-server2 ~]# iptables -A FORWARD --out-interface eth0 --in-interface demo-docker0 -j ACCEPT
[root@test-rook-server2 ~]# iptables -A FORWARD --in-interface eth0 --out-interface demo-docker0 -j ACCEPT
[root@test-rook-server2 ~]# iptables -t nat -A POSTROUTING --source 10.0.0.0/24 --out-interface eth0 -j MASQUERADE

# 测试
[root@test-rook-server2 ~]# ip netns exec demo ping 114.114.114.114 -c 3
PING 114.114.114.114 (114.114.114.114) 56(84) bytes of data.
64 bytes from 114.114.114.114: icmp_seq=1 ttl=250 time=5.13 ms
64 bytes from 114.114.114.114: icmp_seq=2 ttl=250 time=4.81 ms
64 bytes from 114.114.114.114: icmp_seq=3 ttl=250 time=3.61 ms
```

- 解决arp内核限制

```
echo 1 > /proc/sys/net/ipv4/conf/<网卡名称>/accept_local
echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter
echo 0 > /proc/sys/net/ipv4/conf/<网卡名称>/rp_filter
```

## 管理网络

> flannel

Flannel是为Kubernetes设计的一种简单易用的容器网络解决方案，将所有的Pod都组织在同一个子网的虚拟大二层网络中,Flannel支持的后端转发方式有UDP，vxlan，host-gw。我们这里讲vxlan作为后端转发模式。

- 点对点vxlan

```
#                                                  对端Underlay地址  本地Underlay地址   物理网络接口
ip link add vxlan0 type vxlan id 1 dstport 4789 remote 172.16.111.132 local 172.16.111.131 dev eth0
ip addr add 172.20.1.2/24 dev vxlan0
ip link set vxlan0 up


ip link add vxlan0 type vxlan id 1 dstport 4789 remote 172.16.111.131 local 172.16.111.132 dev eth0
ip addr add 172.20.1.3/24 dev vxlan0
ip link set vxlan0 up
```

![image-20220224143838939](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251231892.png)

- 多播模式vxlan

```
# 多播模式
ip link add vxlan0 type vxlan id 1  local 172.16.111.131  group 239.1.1.1 dev eth0 dstport 4789
```

- 每个主机都可能有几十甚至上百个虚拟机/容器，需要加入到同一个VLAN中，而每个VLAN在一台主机上仅仅有一个VTEP这个如何建立每个的链接呢。

可以用VETH Pair将容器连接到网桥，然后将VTEP也连接到网桥。VTEP通过物理网络相互联系。

- **分布式控制中心**

由于使用点对点比较复杂，而且某些网络设备不支持多播，而且多播导致的不必要流量，通过在每个VTEP节点部署Agent，Agent联系控制中心，通过Agent获取通信所需要的信息（FDB+ARP）。

- 这个模型是什么就是我们的flannel



![Flannel - 图1](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251231564.png)



![img{512x368}](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251231884.png)

![Flannel](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251231781.jpg)

### 如何通讯

![法兰绒网络流](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251231723.jpg)

> 当 flannel 使用 VXLAN backend 时，会创建一个名为 flannel.<vni> 的 VXLAN 设备，<vni> 代表 VXLAN Network Identifier，在 flannel 中 VNI 默认设置为 1，即默认设备名称为flannel.1 使用 `ip -d link show flannel.1`将显示有关此 VXALN 设备的详细信息

![image-20220222143024397](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251231633.png)

- 输出所示，vxlan id 为 1，eth0 设备用于隧道，VXLAN UDP 端口为 8472，nolearning 标记禁用源地址学习意味着不使用组播，而是使用带有静态 L3 条目的单播

![image-20220222143239163](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251231504.png)

![image-20220222144605420](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251231359.png)

>  VXLAN 设备 flannel.1 与物理网络设备 eth0 链接，通过物理网络发送 VXLAN 流量。代理`flanneld`将填充节点 ARP 表以及网桥转发数据库，因此 flannel.1 知道如何转发物理网络内的流量。当找到新的 kubernetes 节点时（无论是在启动期间还是在创建时），`flanneld`添加

- 远程节点的 VXLAN 设备的 ARP 条目。(VXLAN设备IP->VXLAN设备MAC)
- 远程主机的 VXLAN fdb 条目。（VXLAN 设备 MAC->远程节点 IP）

注：ARP是三层转发，FDB是用于二层转发

![image-20220222150736174](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251231760.png)

![image-20220222152513891](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251231081.png)

### 手动配置IP地址流程

#### 网络插件流程模拟

```
mkdir /test-cni
cd /test-cni
cat > /test-cni/demo.conf <<"EOF"
{
    "cniVersion": "0.3.1",
    "name": "demo",
    "type": "bridge",
    "bridge": "demo-br0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "subnet": "10.100.10.0/24",
        "routes": [
            { "dst": "0.0.0.0/0" }
        ],
        "rangeStart": "10.100.10.8",
        "rangeEnd": "10.100.10.100",
        "gateway": "10.100.10.1"
    }
}
EOF
cd /opt/cni/bin
ip netns add demo
ip netns list
CNI_COMMAND=ADD CNI_CONTAINERID=demo CNI_NETNS=/var/run/netns/demo CNI_IFNAME=eth0 CNI_PATH=/opt/cni/bin ./bridge </test-cni/demo.conf
```

![image-20220221183140585](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251232257.png)

![image-20220224160105250](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251232486.png)

#### 查看模拟结果

```
ip a
ip netns exec demo ip a show
iptables-save |grep demo
brctl show
```

![image-20220221183505929](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251232578.png)

```
ip netns exec demo ip route 
ls /var/lib/cni/networks/demo

ip netns exec demo ip link set dev lo up

ip netns exec demo ping 10.100.10.1 -c 3
ping 10.100.10.8 -c 3
```

![image-20220221183639550](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251232281.png)

```
ip netns exec demo ethtool -S eth0
 ip link show | grep '^11:'
```

![image-20220221184142075](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251232529.png)

### 模拟flannel 二进制配置测试？

```
ip netns add flannel-demo
ip netns list
CNI_COMMAND=ADD CNI_CONTAINERID=flannel-demo CNI_NETNS=/var/run/netns/flannel-demo CNI_IFNAME=eth0 CNI_PATH=/opt/cni/bin ./flannel </etc/cni/net.d/10-flannel.conflist
```

![image-20220221184643631](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251232952.png)

```
ip a
ip netns exec demo ip a show
iptables-save |grep demo
brctl show
```

![image-20220221184727197](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251232877.png)

```
ip netns exec flannel-demo ip route 
ls /var/lib/cni/networks/cbr0

ip netns exec flannel-demo ip link set dev lo up

ip netns exec flannel-demo ping 172.199.0.1 -c 3
ping 172.199.0.2 -c 3
```

![image-20220221185340117](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251232558.png)

#### flannel二进制和bridge区别

> 手动执行flannel和bridge区别过程有什么区别呢
>
> 手动执行flannel和kubelet调用flannel有什么区别呢

```
# 使用bridge的配置和flannel的配置差别
ip netns exec demo ip route show
ip netns exec flannel-demo ip route show
# 网段没写，怎么自动配置了呢
读取了/run/flannel/subnet.env
# 没写网关，自动创建flannel写入
cat /etc/cni/net.d/10-flannel.conflist
```

![image-20220221185752108](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251232054.png)

### flannel二进制网络和我们手动创建pod时候区别。

- 自动化写入网关
- CNI_NETNS在哪里/var/lib/docker/netns
- /run/flannel/subnet.env

#### 什么了解flannel作用

![Flannel - 图2](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251232275.png)

#### 了解创建组件的大致流程

![kubelet-cri-cni-flowchart](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251232205.png)

#### 创建IP的细节

![kubelet-cri-cni-interactions](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202203251232378.png)

### flannel还有什么问题吗？

- MTU为什么不是1500？

> MTU为最大传输单元为1500，那我们为什么要设置1450呢，由于我们使用vxlan封包，新增了头数据，这样数据切片不会大于1450，新增vxlan头信息则不会大于1500，则在传输过程中就不会丢弃该包。

- system 242导致的问题

当使用 systemd 242+ 运行 flannel 时，在 flannel 对 flannel.1 接口的 mac 地址进行编程和 systemd 在虚拟接口上对 mac 地址进行编程之间似乎存在竞争条件。由于不正确的目标 vtep mac，这会导致在目标节点的第 2 层丢弃所有跨节点流量

原因： mac 地址被更改了两次，第一次由 flannel 更改，第二次由 systemd 根据其默认策略更改为不同的地址

解决办法：

```
cat<<'EOF'>/etc/systemd/network/10-flannel.link
[Match]
OriginalName=flannel*

[Link]
MACAddressPolicy=none
EOF
```

