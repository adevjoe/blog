---
title: "Redis Cluster 部署"
date: 2021-03-02T20:32:17+08:00
lastmod: 2021-07-14T21:14:22+08:00
draft: false
keywords: ["Redis", "Redis Cluster", "Installation"]
description: "用 Docker 部署 Redis 集群"
tags: ["Redis", "Redis Cluster"]
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

Redis 官方支持集群部署，能够横向扩展 Redis 数据节点。当我们的 Redis 需要大数据量存储时，使用集群模式是一个好的选择，集群模式下，数据会分布到所有节点中。同时，由于 Redis Cluster 的特性使它不支持一些原生 Redis 命令，在架构选型中，我们需要权衡利弊。这篇文章将介绍如何用 Docker 部署一个 Redis 集群。



<!--more-->



### 部署架构

在部署之前，我们先看一下 Redis 集群模式的部署架构。Redis 从 3.0 开始正式支持集群模式，通过 `cluster-enabled yes` 参数，我们可以开启集群模式。集群模式至少需要 6 个节点才能组成一个高可用集群，这篇示例中，我们将使用 6 个 Redis 节点加一个 Redis Cluster Proxy 节点。集群的拓扑如下图所示。

![Redis-Cluster-Arch](https://images.adevjoe.com/2021-07-14-Eottcc.png)

### 部署物料

本地简单地部署 Redis Cluster，我们可以用 Docker Compose，[这里](https://github.com/adevjoe/redis-simple)准备了集群模式的 `docker-compose.yaml`。compose 文件中包含 6 个 Redis 节点和一个 Redis Cluster Proxy，为了固定节点 IP，我在其中创建了一个子网。`cluster` 目录中还有一个 `setup.sh` 脚本，这个脚本用来初始化 Redis 集群，主要有三步。第一步是节点握手，让节点间互相建立通信关系。第二步给三个主节点添加 slot，slot 用来做 Redis 集群的数据分布。slot 一共有 16384 个，只有全部 slot 都被分配到节点上了，集群才会 Ready。第三步，为每个主节点设置一个从节点，让集群具备高可用能力。

```shell
#!/bin/bash

# meet
for i in $(seq 1 6)
do
  REDIS_IP[$i]=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' redis-$i)
  docker exec redis-1 redis-cli -p 7001 cluster meet ${REDIS_IP[$i]} 700$i
done

# add slots
docker exec redis-1 redis-cli -p 7001 cluster addslots {0..5461}
docker exec redis-2 redis-cli -p 7002 cluster addslots {5462..10922}
docker exec redis-3 redis-cli -p 7003 cluster addslots {10923..16383}

# set slave
docker exec redis-4 redis-cli -p 7004 cluster replicate $(docker exec redis-1 redis-cli -p 7001 cluster nodes | grep ${REDIS_IP[1]} | awk '{print $1}')
docker exec redis-5 redis-cli -p 7005 cluster replicate $(docker exec redis-1 redis-cli -p 7001 cluster nodes | grep ${REDIS_IP[2]} | awk '{print $1}')
docker exec redis-6 redis-cli -p 7006 cluster replicate $(docker exec redis-1 redis-cli -p 7001 cluster nodes | grep ${REDIS_IP[3]} | awk '{print $1}')

# restart redis-cluster-proxy
docker stop redis-cluster-proxy && docker start redis-cluster-proxy
```



### 执行命令

准备好 `docker-compose` 文件后，我们就可以部署了。在 [cluster](https://github.com/adevjoe/redis-simple/tree/main/cluster) 目录中启动 docker-compose。

```shell
$ cd cluster
$ docker-compose up -d
```

待容器都起来后，执行集群初始化脚本 `setup.sh`。

```shell
$ ./setup.sh
OK
OK
OK
OK
OK
OK
OK
OK
OK
OK
OK
OK
redis-cluster-proxy
redis-cluster-proxy
```

接着看一下 Redis 容器状态。

```shell
$ docker ps -a | grep redis
1cb194d523fe   adevjoe/redis-cluster-proxy:0.0.1     "/usr/local/bin/redi…"   37 minutes ago   Up 11 seconds              0.0.0.0:7777->7777/tcp, :::7777->7777/tcp                                                                                              redis-cluster-proxy
1dd95cc9fa79   redis:6.0                             "docker-entrypoint.s…"   37 minutes ago   Up 37 minutes              6379/tcp, 0.0.0.0:7003->7003/tcp, :::7003->7003/tcp                                                                                    redis-3
03e58f05fdd8   redis:6.0                             "docker-entrypoint.s…"   37 minutes ago   Up 37 minutes              6379/tcp, 0.0.0.0:7001->7001/tcp, :::7001->7001/tcp                                                                                    redis-1
9dd2549ee587   redis:6.0                             "docker-entrypoint.s…"   37 minutes ago   Up 37 minutes              6379/tcp, 0.0.0.0:7002->7002/tcp, :::7002->7002/tcp                                                                                    redis-2
fe172daf9d7c   redis:6.0                             "docker-entrypoint.s…"   37 minutes ago   Up 37 minutes              6379/tcp, 0.0.0.0:7006->7006/tcp, :::7006->7006/tcp                                                                                    redis-6
60a0b73ad88a   redis:6.0                             "docker-entrypoint.s…"   37 minutes ago   Up 37 minutes              6379/tcp, 0.0.0.0:7004->7004/tcp, :::7004->7004/tcp                                                                                    redis-4
b5697ece616a   redis:6.0                             "docker-entrypoint.s…"   37 minutes ago   Up 37 minutes              6379/tcp, 0.0.0.0:7005->7005/tcp, :::7005->7005/tcp                                                                                    redis-5
```

登入一个 Redis 容器，查看集群状态。

```shell
$ docker exec redis-1 redis-cli -p 7001 cluster info
cluster_state:ok
cluster_slots_assigned:16384
cluster_slots_ok:16384
cluster_slots_pfail:0
cluster_slots_fail:0
cluster_known_nodes:6
cluster_size:3
cluster_current_epoch:5
cluster_my_epoch:1
cluster_stats_messages_ping_sent:140
cluster_stats_messages_pong_sent:155
cluster_stats_messages_meet_sent:6
cluster_stats_messages_sent:301
cluster_stats_messages_ping_received:154
cluster_stats_messages_pong_received:146
cluster_stats_messages_meet_received:1
cluster_stats_messages_received:301
```

可以看到 `cluster_state` 为 `ok`，且 16384 个 slot 都被分配了。

在上面的容器列表中，有个容器的端口为 `7777` ，这就是 Redis Cluster Proxy 容器，可以用来代理 Redis 节点。通过 proxy 我们可以在 Docker 网络外访问 Redis。

```shell
$ redis-cli -p 7777
127.0.0.1:7777> set a 1
OK
127.0.0.1:7777> get a
"1"
127.0.0.1:7777> proxy info
# Proxy
proxy_version:v3.6.0-sdgsdkh
proxy_git_sha1:00000000
proxy_git_dirty:0
proxy_git_branch:
os:Linux 5.10.25-linuxkit x86_64
arch_bits:64
multiplexing_api:epoll
gcc_version:9.3.0
process_id:1
threads:8
tcp_port:7777
uptime_in_seconds:302
uptime_in_days:0
config_file:
acl_user:default

# Memory
used_memory:7848539
used_memory_human:7.48M
total_system_memory:2083807232
total_system_memory_human:1.94G

# Clients
connected_clients:1
max_clients:10000
thread_0_clinets:1
thread_1_clinets:0
thread_2_clinets:0
thread_3_clinets:0
thread_4_clinets:0
thread_5_clinets:0
thread_6_clinets:0
thread_7_clinets:0

# Cluster
address:10.5.0.11:7001
entry_node:10.5.0.11:7001
127.0.0.1:7777>
```

（完）
