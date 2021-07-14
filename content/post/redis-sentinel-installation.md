---
title: "Redis Sentinel 部署"
date: 2021-01-25T14:22:17+08:00
lastmod: 2021-07-08T01:00:17+08:00
draft: false
keywords: ["Redis", "Sentinel", "Installation"]
description: "用 Docker 部署 Redis 哨兵实例"
tags: ["Redis", "Sentinel"]
categories: ["Redis"]
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

从 Redis 2.8 开始，Sentinel 正式成为 Redis 官方高可用解决方案。通过 Redis Sentinel 这套架构，它能够自动发现故障节点并自动进行主从切换。同时 Sentinel 也一直更新主节点的信息，客户端与 Sentinel 通信可以获取最新的主节点 IP。本文将介绍如何用 Docker 部署 Redis Sentinel。



<!--more-->



### 部署架构

首先，我们了解下 Redis Sentinel 的架构和各个组件的作用。一般我们说 Redis Sentinel，代表着一套高可用解决方案。 这一套高可用架构中，分别有两种组件，Redis 和 Sentinel。它们都位于 Redis 代码仓库中，且一起被编译在一个二进制执行文件里，Redis 启动命令为 `redis-server`，Sentinel 启动命令为 `redis-server --sentinel`。这套架构中，Sentinel 节点负责监控 Redis 节点，自动进行故障发现和故障转移。Redis 节点架构为 1 主多从，数据同步通过主从复制模式来实现。Redis Sentinel 是从主从复制进化而来的，Sentinel 相当于是额外的组件，不会对 Redis 节点做修改。Redis 组件至少需要两个节点，一个主节点和 N 个从节点，Sentinel 最少需要 3 个节点。节点拓扑结构如下所示。

![Redis Sentinel](https://images.adevjoe.com/2021-07-12-V09nvH.png)

### 部署物料

借助 Docker 和 Docker Compose，我们可以很方便地安装部署 Redis Sentinel。我准备了一个 [docker-compose.yaml](https://github.com/adevjoe/redis-simple)，文件中配置了 3 个 Redis 节点和 3 个 Sentinel 节点。其中 Sentinel 的配置文件可以共用，主要配置如下：

```
# sentinel monitor <master-group-name> <ip> <port> <quorum>
sentinel monitor mymaster redis-data-1 7001 2
sentinel down-after-milliseconds mymaster 1000
```

### 启动命令

准备好 `docker-compose` 文件后，我们就可以部署了。在 [failover](https://github.com/adevjoe/redis-simple/tree/main/failover) 目录中启动 docker-compose。

```shell
cd failover
docker-compose up -d
```

待命令执行完成后，就部署完成了，我们可以查看一下所有启动的容器。

```shell
$ docker ps -a
CONTAINER ID   IMAGE                              COMMAND                  CREATED         STATUS                     PORTS                                                                                                                                  NAMES
1cce2f0f1749   redis:6.0                          "docker-entrypoint.s…"   3 minutes ago   Up 3 minutes               6379/tcp, 0.0.0.0:8006->7006/tcp, :::8006->7006/tcp                                                                                    sentinel-3
173cab5d4bde   redis:6.0                          "docker-entrypoint.s…"   3 minutes ago   Up 2 minutes               6379/tcp, 0.0.0.0:8004->7004/tcp, :::8004->7004/tcp                                                                                    sentinel-1
3633c0faad12   redis:6.0                          "docker-entrypoint.s…"   3 minutes ago   Up 3 minutes               6379/tcp, 0.0.0.0:8005->7005/tcp, :::8005->7005/tcp                                                                                    sentinel-2
ff15899b9c2b   redis:6.0                          "docker-entrypoint.s…"   3 minutes ago   Up 3 minutes               6379/tcp, 0.0.0.0:8003->7003/tcp, :::8003->7003/tcp                                                                                    redis-data-3
88314ef8e717   redis:6.0                          "docker-entrypoint.s…"   3 minutes ago   Up 3 minutes               6379/tcp, 0.0.0.0:8001->7001/tcp, :::8001->7001/tcp                                                                                    redis-data-1
ff487b310dca   redis:6.0                          "docker-entrypoint.s…"   3 minutes ago   Up 3 minutes               6379/tcp, 0.0.0.0:8002->7002/tcp, :::8002->7002/tcp                                                                                    redis-data-2
```

查看 Sentinel 信息

```shell
$ docker exec sentinel-1 redis-cli -p 7004 info sentinel

# Sentinel
sentinel_masters:1
sentinel_tilt:0
sentinel_running_scripts:0
sentinel_scripts_queue_length:0
sentinel_simulate_failure_flags:0
master0:name=mymaster,status=ok,address=172.22.0.3:7001,slaves=2,sentinels=3
```

测试 Redis 连接，这里的 IP 填上一步从 Sentinel 获取的 Redis 主节点 IP。

```shell
$ docker exec sentinel-1 redis-cli -h 172.22.0.3 -p 7001 set a 1
OK
$ docker exec sentinel-1 redis-cli -h 172.22.0.3 -p 7001 get a
1
```

（完）
