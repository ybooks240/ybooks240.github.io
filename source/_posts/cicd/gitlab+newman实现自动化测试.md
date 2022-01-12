---
title: gitlab+newman实现自动化测试
date: 2022-01-11 11:40:35
author:  
toc: true
mathjax: false
summary: 初探newman实现自动化测试报告
categories: cicd

tags:
  - cicd
  - newman
---

# 使用

```
npm install -g newman
npm install -g newman-reporter-html
newman run examples/sample-collection.json
newman run examples/sample-collection.json -r html
# 生产报告在当前的目录下的newman内
```
# 结果截图
![生成的报告](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121203986.png)

# 易错点
> 安装newman-reporter-html错误
```
[root@test2 sendEmail]# newman run scripts/web.postman_collection.json  -r html
newman: "html" reporter could not be loaded.
  run `npm install newman-reporter-html`

[root@test2 sendEmail]# npm install newman-reporter-html
npm WARN saveError ENOENT: no such file or directory, open '/SHELL/autoTest/sendEmail/package.json'
npm notice created a lockfile as package-lock.json. You should commit this file.
npm WARN enoent ENOENT: no such file or directory, open '/SHELL/autoTest/sendEmail/package.json'
npm WARN newman-reporter-html@1.0.3 requires a peer of newman@4 but none is installed. You must install peer dependencies yourself.
npm WARN sendEmail No description
npm WARN sendEmail No repository field.
npm WARN sendEmail No README data
npm WARN sendEmail No license field.

+ newman-reporter-html@1.0.3
added 13 packages from 45 contributors and audited 14 packages in 1.615s
found 1 high severity vulnerability
  run `npm audit fix` to fix them, or `npm audit` for details
[root@test2 sendEmail]# npm audit fix
npm ERR! code EAUDITNOPJSON
npm ERR! audit No package.json found: Cannot audit a project without a package.json

npm ERR! A complete log of this run can be found in:
npm ERR!     /root/.npm/_logs/2019-07-18T08_27_23_701Z-debug.log

```
* 问题截图
![生产报告安装newman-reporter-html报错](https://buleye.oss-cn-shenzhen.aliyuncs.com/images/202201121203417.png)

* 解决办法
```
npm install -g newman-reporter-html
```

# 参考文档
[参考文档](https://www.npmjs.com/package/newman)