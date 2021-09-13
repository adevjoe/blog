---
title: "我如何搭建自己的知识管理系统"
author: "Joe"
date: 2021-09-13T15:07:18+08:00
lastmod: 2021-09-13T15:07:18+08:00
draft: false
description: "我如何搭建自己的知识管理系统"
keywords:
  - KMS
  - Knowledge Management System
tags:
  - KMS
  - Learning
  - Note
categories:
  - Learning
  - Note
---

<!-- Abstract -->
根据  [笔记文件分类](https://web.archive.org/web/20210907090618/https://www.zhihu.com/question/23427617/answer/70809840)、 [知识管理系统搭建](https://web.archive.org/web/20210907091351/https://zhuanlan.zhihu.com/p/191519306) 、[使用 Obsidian 构建写作体系](https://www.youtube.com/watch?v=431M1q8tlTI) 相关资料，我总结了自己知识管理系统。总体上，分三步走，输入（资料收集）、处理（资料整理吸收、做笔记、归档）、输出（整理成文章），全部的步骤都由 [Obsidian](https://obsidian.md/) 来完成。
## 知识输入
从各处来源收集到 `Knowledge -> A. Inbox` 文件夹中，定期（每晚或者周末）整理。`Inbox` 中还会有 `ZK`[^1] 笔记，用来记录一些灵感或者临时的一些想法。



<!--more-->



<!-- Content -->
### 来源
- RSS，我使用 [NetNewsWire](https://netnewswire.com/) 来订阅，支持 Mac 和 iOS，可以通过 iCloud 和其他途径同步，开源且免费。这是我的主要信息来源，里面订阅了一些个人技术博客、大公司的技术博客、开源软件信息和博客、YouTube 频道、科技资讯等。
- Telegram，订阅了一些频道，[rss_kubernetes](https://t.me/rss_kubernetes) 、[Newlearner](https://t.me/NewlearnerChannel) 、[程序员技术资源分享](https://t.me/gotoshare) 等。
- Newsletter，主要是 Kubernetes、Go、Redis 的一些邮件组和 [Shyrism.News](https://shyrz.substack.com/) 之类的资讯。
- YouTube
- GitHub，关注用户的 star 和参加的项目，趋势榜等。
- V2EX/Reddit/Stack Overflow 等一些讨论 
- 开源软件文档

## 知识整理
定期从 `Inbox` 整理资料，也有可能是即时整理的。资料可能是一段话、一片文章、一个技术点，结合阅读、搜索，把对应的知识整理成结构化的内容，然后建立索引、放入对应的文件夹中。

### 知识结构
为了知识成体系化，存入知识库的需要经过整理和消化，用自己语言来描述整个技术的背景、方案、使用、实践等等。大体分为三大块：
1. What，是什么
2. Why，为什么需要这个
3. How，怎么做，有什么解决方案

### 文件分类规则
根据 `GTD`[^2] 工作流中 5 个步骤：收集、厘清、整理、归档、回顾，我制定了一些一级目录。
- Inbox：用来收集资料
- Navigation：用来索引知识，建立结构化
- Knowledge：用来存储结构化知识
- Template: 一些模板，用来快速创建笔记
- Attachments：资源目录，用来存储图片、PDF 等
- Archive：归档，用来存储一些过时或者用不到的知识

Navigation 和 Knowledge 主要分为五类
- Programming：编程类的都在这里
- Learning：英语学习、阅读、工作方法学习等
- Life：生活经验、家庭朋友关系、成长、做饭、好物等
- Interest：爱好，音乐、画画、游泳运动等
- Career: 职业发展之类的在这里

Navigation 主要索引一些二级分类，Knowledge 存放具体的笔记。每个 Knowledge 二级目录中都包含一个索引，索引具体的笔记。

![文件结构|200](https://images.adevjoe.com/2021-09-13-1Kw1Yx.png)


## 知识输出
通过索引和文件分类，可以很快找到对应的笔记和知识点。借助 `Obsidian` 的 graph 视图，可以看到整体的知识网络。下面是我的知识网状图，慢慢积累，逐渐完善我的知识体系。从开始暗淡的星星点点，到整片璀璨的知识星系，是我们打造知识库的见证。
![my-knowledge-graph|500](https://images.adevjoe.com/2021-09-13-CXe8Rz.png)

## 任务规划
根据 `GTD` 和 `OKR` 规划我的目标。
`OKR` 用来指定年计划，记录在 `TickTick` 中。
`GTD` 用来指定每天、每周的计划，也记录在 `TickTick` 中。

## 迭代维护
- 玩熟软件，Obsidian 和 TickTick
- 规律性清理 `Inbox`，每周要有固定时间清理
- 迭代内容，清理过时内容，一些不需要的可以放入 `Archive`。需要时常翻阅，可以通过索引来翻阅，也可以通过随机来翻阅。

[^1]: https://en.wikipedia.org/wiki/Zettelkasten
[^2]: https://en.wikipedia.org/wiki/Getting_Things_Done
