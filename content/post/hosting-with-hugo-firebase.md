---
title: "Hugo + Firebase + Gitlab 自动化部署你的网站"
date: 2018-11-05
lastmod: 2018-11-11
draft: false
keywords: ["Hugo", "Firebase", "CI/CD", "Gitlab"]
description: "使用 Hugo 和 Firebase 搭建静态网站，构建自动化部署。"
tags: ["Hugo", "Firebase", "CI/CD", "Gitlab"]
categories: ["Hugo", "Firebase", "CI/CD", "Gitlab"]
author: "Joe"

# You can also close(false) or open(true) something for this content.
# P.S. comment can only be closed
comment: true
toc: true
autoCollapseToc: false
# You can also define another contentCopyright. e.g. contentCopyright: "This is another copyright."
contentCopyright: <a rel="license noopener" href="https://creativecommons.org/licenses/by-nc-nd/4.0/deed.zh" target="_blank">CC BY-NC-ND 4.0</a>
reward: false
mathjax: false
---


<!-- Edit Replace Here.-->
又折腾了一下博客，这次把博客搭在 Firebase 上面，并使用了 Gitlab CI。博客仓库主分支接收到推送事件后，
会自动生成 Hugo 博客静态文件，并通过 Firebase SDK 部署到 Firebase Hosting。整个流程舒畅无比，
这种感觉还是很爽的。

<!--more-->
## 瞎扯

博客生成器依旧使用 Hugo，不得不说 Hugo 生成网站是真的快，各种插件和主题也是很多，可以很方便地自定义自己的博客。

这次迁移到 Firebase，主要是对 Google Cloud Platform 以及 Firebase 一系列生态的体验和尝试。

Firebase 对移动应用的帮助真的非常大，能快速对接第三方登录系统，有实时的数据库，不需要后端支持就可以拥有存储系统，并运行云端的函数，
我正在使用的 Hosting(静态网站托管)也是其中一项，Hosting 能自动开启 SSL，不需要自己配置。同时搭配的一系列数据分析和 A/B 测试服务，
对应用成长作用巨大。

![Jietu20181111-210825.jpg](https://i.loli.net/2018/11/11/5be829d82a1a1.jpg)

## 这些是需要的

- Git
- Gitlab 账号，并建好仓库。
- [Hugo](https://gohugo.io/)，可以本地预览。
- Firebase 账号。

## 步骤

如果只需要本地部署 Firebase，那么可以直接看 [官网](https://gohugo.io/hosting-and-deployment/hosting-on-firebase/) 的教程。

### 1. 创建 Firebase 项目

在 [Firebase控制台](https://console.firebase.google.com/)创建好项目，步骤就不细说了。

### 2. 本地部署 Firebase 项目

````shell
// 安装 Firebase 工具
$ npm install -g firebase-tools

// 登录之前创建的项目
$ firebase login

// 初始化项目
$ firebase init

// 生成网站静态文件并部署
$ hugo && firebase deploy
````

接着 Firebase 项目中应该有了发布记录，可以用访问看看有没有变化。

![Jietu20181111-212541.jpg](https://i.loli.net/2018/11/11/5be82de5dc37c.jpg)

### 3. 编写 Gitlab CI 配置文件

在仓库根目录添加 `.gitlab-ci.yml` 文件，内容如下：
````yml
image: nohitme/hugo-firebase

before_script:
  - hugo version
  - firebase --version

hugo_firebase:
  stage: deploy
  only:
    - master
  except:
    - dev
  script:
  - rm -rf public
  - hugo
  - firebase deploy --token ${FIREBASE_TOKEN}
````

镜像使用的是 [nohime](https://github.com/nohitme/docker-hugo-firebase) 这位兄弟的。

### 4. 获取 Firebase CI Token

````shell
$ firebase login:ci
````

这个过程需要翻墙，**特别要注意不要泄露了 Token**。

### 5. Gitlab 配置

在 gitlab 仓库设置中添加上一步获取的 token，变量名是 `FIREBASE_TOKEN`

![Jietu20181111-213404.jpg](https://i.loli.net/2018/11/11/5be82fda89f50.jpg)

### 6. 推送仓库

commit 并 push 到 gitlab，此时在 gitlab 仓库中的 CI/CD 菜单就能看到构建的项目了。

![Jietu20181111-213916.jpg](https://i.loli.net/2018/11/11/5be83113f11e2.jpg)

感兴趣的可以尝试一波哟！
