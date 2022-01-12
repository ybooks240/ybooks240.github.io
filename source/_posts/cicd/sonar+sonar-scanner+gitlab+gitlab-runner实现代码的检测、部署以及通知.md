---
title: sonar+sonar-scanner+gitlab+gitlab-runner实现代码的检测、部署以及通知
date: 2022-01-10 11:40:35
author:  
img: https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121202334.png
top: true
hide: false
cover: true
coverImg: https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121153157.png
toc: true
mathjax: false
summary: 随着工作量越来越大，我们需要保证我们的工作效率的同时保证我们的代码的质量，所以我们需要一些自动化的东西加入到我们的工作中自动化部署、自动化测试、自动化通知等
categories: cicd
tags:
  - cicd
  - sonar+sonar
  - scanner
  - gitlab
  - gitlab-runner
  - kubernetes
---

# 前言

随着工作量越来越大，我们需要保证我们的工作效率的同时保证我们的代码的质量，所以我们需要一些自动化的东西加入到我们的工作中
自动化部署、自动化测试、自动化通知等。

# 文章内容
改文章主要简述如何通过sonar进行代码检测
如何实现自动部署和自动检测将在下一篇中简述

# 什么是sonar
[官网地址](https://www.sonarqube.org/)
sonar实现对静态代码的扫描，给我对代码质量、安全的解析
#  需要实现功能
* 一台centos7 服务器
  * 安装gitlab
  * 安装sonar
  * 安装sonar数据库
* 一台客户端服务器
  * 安装gitlab-runner
  * 安装sonar-scanner
  * 安装构建java的maven
* 实现功能，通过gitlab推送代码到gitlab服务器，gitlab通过gitlab-runner实现触发，通过.gitlab-ci.yml控制触发后流程，再流程中通过脚本实现对代码的检测，对代码的构建，对代码的部署，对部署结果的通知到企业微信。
![实现结果图](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121149889.png)

# 安装
* sonarqube-7.9就不支持mysql

> 下载sonar

```shell
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-7.8.zip
```

> 创建数据库

```shell
# 编写docker-compose.yml
vim docker-compose.yml 

version: '3.3'

services:
  sonarqube_mysql:
    environment:
        MYSQL_ROOT_PASSWORD: 123456
    image: mysql:5.7
    restart: always
    volumes:
        - /ENV/mysql/sonarqube/mysql/data/:/var/lib/mysql/
        - /ENV/mysql/sonarqube/mysql/conf/:/etc/mysql/
    ports:
        - 3306:3306
    container_name: sonarqube_mysql
    


# 创建对应目录并启动
mkdir /ENV/mysql/sonarqube/mysql/{data,conf} -p
docker-compose up -d
# 连接上mysql创建数据库sonar
create database sonar default character set utf8 collate utf8_general_ci;
# 授权
grant all on sonar.* to sonar@'%' identified by '123456';
```

> 编辑配置文件
```
vim sonar.properties
sonar.jdbc.username=sonar
sonar.jdbc.password=123456
sonar.jdbc.url=jdbc:mysql://192.168.0.71:3306/sonar?useUnicode=true&characterEncoding=utf8&rewriteBatchedStatements=true&useConfigs=maxPerformance&useSSL=false
< sonar.host.url >http://192.168.0.71:9000</ sonar.host.url > <!-- Sonar服务器访问地址 -->
sonar.login=admin
sonar.password=admin
sonar.web.host=0.0.0.0
sonar.web.port=9000
```
> 启动进入web打开URL:9000
```
su sonar ./sonar.sh start
```
> 安装sonar-scan
* 下载sonar-scanner-cli-4.0.0.1744-linux.zip
```
# 页面地址
https://docs.sonarqube.org/latest/analysis/scan/sonarscanner/
# 下载地址
wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.0.0.1744-linux.zip
```
* 解压
```
unzip sonar-scanner-cli-4.0.0.1744-linux.zip
```
* 配置PATH

```
ln -s sonar-scanner-cli-4.0.0.1744-linux sonar-scanner
vim /etc/profile
export PATH=$PATH:/INSTALL/sonar/PATH/sonar-scanner/bin
source /etc/profile
```
---
> 扫描java
* 服务端页面创建项目
![点击+创建项目](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121149330.png)

![输入项目名字](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121149740.png)
![得到token](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121149221.png)
![得到token](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121149687.png)

![image.png](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121149519.png)

* 服务器上运行
```
# 需要加最后一行，否则会报错
mvn sonar:sonar \
  -Dsonar.projectKey=test_java \
  -Dsonar.host.url=http://192.168.0.71:9000 \
  -Dsonar.login=d003e898d6a34d0db25b255cbbe66a6bd771c746
  -Dsonar.java.binaries=target/sonar
```
* 页面刷新可以看到报告
![生成报告页面](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121149989.png)

> 扫描前端（h5,js等）
* 创建项目
![创建项目](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121149197.png)
* 生成token
![生成token](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121149587.png)
* 得到服务器运行命令
![得到命令](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121149932.png)
> 服务器运行
```
sonar-scanner \
  -Dsonar.projectKey=test_web \
  -Dsonar.sources=. \
  -Dsonar.host.url=http://192.168.0.71:9000 \
  -Dsonar.login=06992092bbd9e25758f2b5d047bea4027d46824c
```
* 生成报告
![生成报告](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121149652.png)

---
> 配置中文模块

![配置中文](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121149711.png)
![安装成功，重启服务](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121149048.png)
* 需要5分钟后刷新看结果
![安装中文包成功](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121149354.png)

# sonar 连接gitlab
* 下载gitlab插件
[https://github.com/gabrie-allaigre/sonar-gitlab-plugin/releases](https://github.com/gabrie-allaigre/sonar-gitlab-plugin/releases)
```
wget https://github.com/gabrie-allaigre/sonar-gitlab-plugin/releases/download/3.0.2/sonar-gitlab-plugin-3.0.2.jar
cp sonar-gitlab-plugin-3.0.2.jar  <sonarqube_install_dir>/extensions/plugins
# 重启sonar
# 应用市场安装gitlab相关的插件
```
![安装插件](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121149928.png)

> 配置连接gitlab用户
* 创建gitlab用户，略

![创建tokens](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121149609.png)

> 配置sonar
> ![配置sonar中的gitlab](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121149248.png)

> 

---
# 常见报错
> sonar 应为java版本问题
* 报错日志
```
--> Wrapper Started as Daemon
Launching a JVM...
Wrapper (Version 3.2.3) http://wrapper.tanukisoftware.org
  Copyright 1999-2006 Tanuki Software, Inc.  All Rights Reserved.


WrapperSimpleApp: Encountered an error running main: java.lang.IllegalStateException: SonarQube requires Java 11+ to run
java.lang.IllegalStateException: SonarQube requires Java 11+ to run
        at org.sonar.application.App.checkJavaVersion(App.java:93)
        at org.sonar.application.App.start(App.java:56)
        at org.sonar.application.App.main(App.java:98)
        at sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
        at sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
        at sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
        at java.lang.reflect.Method.invoke(Method.java:498)
        at org.tanukisoftware.wrapper.WrapperSimpleApp.run(WrapperSimpleApp.java:240)
        at java.lang.Thread.run(Thread.java:748)
<-- Wrapper Stopped
```
* 解决办法
```
# 重新下载java
https://www.oracle.com/technetwork/java/javase/downloads/jdk11-downloads-5066655.html
# 配置java虚拟环境则可以
# 查看版本
java -version
java version "11.0.4" 2019-07-16 LTS
Java(TM) SE Runtime Environment 18.9 (build 11.0.4+10-LTS)
Java HotSpot(TM) 64-Bit Server VM 18.9 (build 11.0.4+10-LTS, mixed mode)

```
* 日志报错
```
2019.07.25 11:14:22 WARN  app[][o.s.a.p.AbstractManagedProcess] Process exited with exit value [es]: 1
2019.07.25 11:14:22 INFO  app[][o.s.a.SchedulerImpl] Process[es] is stopped
2019.07.25 11:14:22 INFO  app[][o.s.a.SchedulerImpl] SonarQube is stopped
<-- Wrapper Stopped
```
```
2019.07.25 11:22:29 ERROR es[][o.e.b.Bootstrap] Exception
java.lang.RuntimeException: can not run elasticsearch as root
	at org.elasticsearch.bootstrap.Bootstrap.initializeNatives(Bootstrap.java:103) ~[elasticsearch-6.8.0.jar:6.8.0]
	at org.elasticsearch.bootstrap.Bootstrap.setup(Bootstrap.java:170) ~[elasticsearch-6.8.0.jar:6.8.0]
	at org.elasticsearch.bootstrap.Bootstrap.init(Bootstrap.java:333) [elasticsearch-6.8.0.jar:6.8.0]
	at org.elasticsearch.bootstrap.Elasticsearch.init(Elasticsearch.java:159) [elasticsearch-6.8.0.jar:6.8.0]
	at org.elasticsearch.bootstrap.Elasticsearch.execute(Elasticsearch.java:150) [elasticsearch-6.8.0.jar:6.8.0]
	at org.elasticsearch.cli.EnvironmentAwareCommand.execute(EnvironmentAwareCommand.java:86) [elasticsearch-6.8.0.jar:6.8.0]
	at org.elasticsearch.cli.Command.mainWithoutErrorHandling(Command.java:124) [elasticsearch-cli-6.8.0.jar:6.8.0]
	at org.elasticsearch.cli.Command.main(Command.java:90) [elasticsearch-cli-6.8.0.jar:6.8.0]
	at org.elasticsearch.bootstrap.Elasticsearch.main(Elasticsearch.java:116) [elasticsearch-6.8.0.jar:6.8.0]
	at org.elasticsearch.bootstrap.Elasticsearch.main(Elasticsearch.java:93) [elasticsearch-6.8.0.jar:6.8.0]
2019.07.25 11:22:29 WARN  es[][o.e.b.ElasticsearchUncaughtExceptionHandler] uncaught exception in thread [main]
org.elasticsearch.bootstrap.StartupException: java.lang.RuntimeException: can not run elasticsearch as root
	at org.elasticsearch.bootstrap.Elasticsearch.init(Elasticsearch.java:163) ~[elasticsearch-6.8.0.jar:6.8.0]
	at org.elasticsearch.bootstrap.Elasticsearch.execute(Elasticsearch.java:150) ~[elasticsearch-6.8.0.jar:6.8.0]
	at org.elasticsearch.cli.EnvironmentAwareCommand.execute(EnvironmentAwareCommand.java:86) ~[elasticsearch-6.8.0.jar:6.8.0]
	at org.elasticsearch.cli.Command.mainWithoutErrorHandling(Command.java:124) ~[elasticsearch-cli-6.8.0.jar:6.8.0]
	at org.elasticsearch.cli.Command.main(Command.java:90) ~[elasticsearch-cli-6.8.0.jar:6.8.0]
	at org.elasticsearch.bootstrap.Elasticsearch.main(Elasticsearch.java:116) ~[elasticsearch-6.8.0.jar:6.8.0]
	at org.elasticsearch.bootstrap.Elasticsearch.main(Elasticsearch.java:93) ~[elasticsearch-6.8.0.jar:6.8.0]
Caused by: java.lang.RuntimeException: can not run elasticsearch as root
	at org.elasticsearch.bootstrap.Bootstrap.initializeNatives(Bootstrap.java:103) ~[elasticsearch-6.8.0.jar:6.8.0]
	at org.elasticsearch.bootstrap.Bootstrap.setup(Bootstrap.java:170) ~[elasticsearch-6.8.0.jar:6.8.0]
	at org.elasticsearch.bootstrap.Bootstrap.init(Bootstrap.java:333) ~[elasticsearch-6.8.0.jar:6.8.0]
	at org.elasticsearch.bootstrap.Elasticsearch.init(Elasticsearch.java:159) ~[elasticsearch-6.8.0.jar:6.8.0]
	... 6 more
```
* 解决办法
```
# 使用非root启动
su sonar ./bin/linux-x86-64/sonar.sh status
```
* elasticsearch process is too low日志报错
```
[root@test2 logs]# tailf es.log 
2019.07.25 11:26:25 INFO  es[][o.e.t.TransportService] publish_address {127.0.0.1:9001}, bound_addresses {127.0.0.1:9001}
2019.07.25 11:26:25 INFO  es[][o.e.b.BootstrapChecks] explicitly enforcing bootstrap checks
2019.07.25 11:26:25 ERROR es[][o.e.b.Bootstrap] node validation exception
[2] bootstrap checks failed
[1]: max file descriptors [4096] for elasticsearch process is too low, increase to at least [65535]
[2]: max virtual memory areas vm.max_map_count [65530] is too low, increase to at least [262144]
2019.07.25 11:26:25 INFO  es[][o.e.n.Node] stopping ...
2019.07.25 11:26:26 INFO  es[][o.e.n.Node] stopped
2019.07.25 11:26:26 INFO  es[][o.e.n.Node] closing ...
2019.07.25 11:26:26 INFO  es[][o.e.n.Node] closed
```
* 解决办法
```
vim /etc/security/limits.conf
sonar hard nofile 65536
sonar soft nofile 65536
```
* 没有报错，但是无法启动
```
2019.07.25 12:03:21 INFO  app[][o.s.a.SchedulerImpl] Process[es] is up
2019.07.25 12:03:21 INFO  app[][o.s.a.ProcessLauncherImpl] Launch process[[key='web', ipcIndex=2, logFilenamePrefix=web]] from [/ENV/SonarQube/sonarqube-7.9.1]: /usr/local/jdk-11.0.4/bin/java -Djava.awt.headless=true -Dfile.encoding=UTF-8 -Djava.io.tmpdir=/ENV/SonarQube/sonarqube-7.9.1/temp --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.io=ALL-UNNAMED --add-opens=java.rmi/sun.rmi.transport=ALL-UNNAMED -Xmx512m -Xms128m -XX:+HeapDumpOnOutOfMemoryError -Dhttp.nonProxyHosts=localhost|127.*|[::1] -cp ./lib/common/*:/ENV/SonarQube/sonarqube-7.9.1/lib/jdbc/mysql/mysql-connector-java-5.1.46.jar org.sonar.server.app.WebServer /ENV/SonarQube/sonarqube-7.9.1/temp/sq-process6136915182525445856properties
2019.07.25 12:03:26 INFO  app[][o.s.a.SchedulerImpl] Process[web] is stopped
2019.07.25 12:03:26 INFO  app[][o.s.a.SchedulerImpl] Process[es] is stopped
2019.07.25 12:03:26 WARN  app[][o.s.a.p.AbstractManagedProcess] Process exited with exit value [es]: 143
2019.07.25 12:03:26 INFO  app[][o.s.a.SchedulerImpl] SonarQube is stopped
<-- Wrapper Stopped
```
```
2019.07.25 13:48:36 ERROR web[][o.s.s.p.Platform] Web server startup failed: 
#############################################################################################################
#         End of Life of MySQL Support : SonarQube 7.9 and future versions do not support MySQL.            #
#         Please migrate to a supported database. Get more details at                                       #
#         https://community.sonarsource.com/t/end-of-life-of-mysql-support                                  #
#         and https://github.com/SonarSource/mysql-migrator                                                 #
#############################################################################################################
```
* 解决办法
[参考文档](https://github.com/SonarSource/mysql-migrator)
![不支持mysql](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121149769.png)
[官方说明不支持mysql](https://jira.sonarsource.com/browse/SONAR-12251)

* 错误日志
```
jvm 1    | ERROR: [1] bootstrap checks failed
jvm 1    | [1]: max virtual memory areas vm.max_map_count [65530] is too low, increase to at least [262144]
jvm 1    | 2019.07.26 22:40:45 WARN  app[][o.s.a.p.AbstractManagedProcess] Process exited with exit value [es]: 78
jvm 1    | 2019.07.26 22:40:45 INFO  app[][o.s.a.SchedulerImpl] Process[es] is stopped
jvm 1    | 2019.07.26 22:40:45 INFO  app[][o.s.a.SchedulerImpl] SonarQube is stopped
```
* 解决办法
```
vim /etc/sysctl.conf
vm.max_map_count=655360
sysctl -p
```
* 错误日志
```
Java HotSpot(TM) 64-Bit Server VM 18.9 (build 11.0.4+10-LTS, mixed mode)
[root@test2 ldd-XXX]# mvn sonar:sonar \
>   -Dsonar.projectKey=ldd-attendance \
>   -Dsonar.host.url=http://192.168.0.71:9000 \
>   -Dsonar.login=5f276ec558029a844a4122813d5cda748fdxxxx


[INFO] 1 source files to be analyzed
[INFO] Sensor XML Sensor [xml] (done) | time=11ms
[INFO] 1/1 source files have been analyzed
[INFO] ------------- Run sensors on module front-end
[INFO] Sensor JavaSquidSensor [java]
[INFO] Configured Java source version (sonar.java.source): 8
[INFO] JavaClasspath initialization
[INFO] ------------------------------------------------------------------------
[INFO] Reactor Summary for laodeduo 0.0.1-SNAPSHOT:
[INFO] 
[INFO] laodeduo ........................................... FAILURE [ 14.021 s]
[INFO] model-util ......................................... SKIPPED
[INFO] common-base ........................................ SKIPPED
[INFO] front-end .......................................... SKIPPED
[INFO] back-end ........................................... SKIPPED
[INFO] authe-autho ........................................ SKIPPED
[INFO] ------------------------------------------------------------------------
[INFO] BUILD FAILURE
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  15.581 s
[INFO] Finished at: 2019-07-29T18:46:21+08:00
[INFO] ------------------------------------------------------------------------
[ERROR] Failed to execute goal org.sonarsource.scanner.maven:sonar-maven-plugin:3.6.0.1398:sonar (default-cli) on project laodeduo: Please provide compiled classes of your project with sonar.java.binaries property -> [Help 1]
[ERROR] 
[ERROR] To see the full stack trace of the errors, re-run Maven with the -e switch.
[ERROR] Re-run Maven using the -X switch to enable full debug logging.
[ERROR] 
[ERROR] For more information about the errors and possible solutions, please read the following articles:
[ERROR] [Help 1] http://cwiki.apache.org/confluence/display/MAVEN/MojoExecutionException


```
* 解决办法
```
# 加上   -Dsonar.java.binaries=target/sonar
 mvn sonar:sonar   \
   -Dsonar.projectKey=java  \
   -Dsonar.host.url=http://192.168.0.71:9000  \
   -Dsonar.login=8006f416e06dc8b16fbc32763741cc0d9414xxxx \
   -Dsonar.java.binaries=target/sonar
```