---
title: "一次 Redis 内存占用排查"
date: 2021-03-11
lastmod: 2021-03-11
draft: false
keywords: ["Redis", "Memory", "redis-benchmark"]
description: "排查 Redis Benchmark 导致 Redis 内存逐渐上涨"
tags: ["Redis"]
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

最近在用 redis-benchmark 持续性测试 Redis，在测试过程中发现隔段时间会出现 `No reachable node in cluster` 错误。虽然只是短暂出现几次，但是会影响服务的稳定性，我们需要找出报错的原因。

<!--more-->

### Pod 排查

我们的 Redis 集群是部署在 K8S 上的，首先，检查了一下 Pod 的运行情况，发现有一个 Pod 重启了 5 次。

```
[root@node1 ~]# kubectl -n redis get pod
NAME                                  READY   STATUS    RESTARTS   AGE
redis-cluster-demo-0-0                2/2     Running   0          5d23h
redis-cluster-demo-0-1                2/2     Running   5          5d23h
redis-cluster-demo-1-0                2/2     Running   0          5d23h
redis-cluster-demo-1-1                2/2     Running   0          5d23h
redis-cluster-demo-2-0                2/2     Running   0          5d23h
redis-cluster-demo-2-1                2/2     Running   0          5d23h
```

`redis-cluster-demo-0-1` 是啥情况，为啥重启了 5 次。`No reachable node in cluster` 报错应该就是节点重启导致的。

于是开始日志、事件大法。

```shell
kubectl -n redis logs redis-cluster-demo-0-1 -c redis
```

正在运行的 Pod 日志没啥参考价值，Pod 重启了，之前日志也没了。试试查看一下重启前的 Pod 日志。

登录该 Pod 的机器，看看退出 Pod 的日志。

```shell
# 查看退出容器
docker ps -a | grep <pod_name>

# 查看容器日志
docker logs <container_id>
```

从日志内容看发现也只有启动的信息和 master-replicas connect 的日志。既然日志这里没头绪，就看看事件吧。

```shell
kubectl -n redis describe pod redis-cluster-demo-0-1
```

由于过了几天，事件已经被删除了。还好能看到上次的状态，Pod 被 `OOMKILLED` 了。该 Pod 配了 1Gi 内存限额，按理来说只有 redis-benchmark 应该不会超过 1G，难道哪里有内存泄漏？

![](https://images.adevjoe.com/2021-03-11-XQ6nDK.png)

### Redis 内存排查

先看看 Redis 内存情况。[Info 字段信息](https://redis.io/commands/info)

```shell
redis-cli -h xxx.xxx.xxx.xxx info memory

# 持续观察
watch redis-cli -h xxx.xxx.xxx.xxx info memory
```

`used_memory_human` 在 400M 左右，通过 `watch` 持续查看，发现使用量还在持续上涨。 同时也发现 `allocator_frag_ratio` 在 1 点几，并没有很大，那么这些内存都是正常 key 占用的。难道一直执行 redis-benchmark 会导致内存上涨？测试的数据不能自动清理吗？百思不得其解，先用 `dbsize` 看下 key 的数量，也就几个。key 数量不大，再通过 `--bigkeys` 分析一下有没有大 key，发现一个 list 居然有几十万的元素。

```shell
# 查看 key 数量
redis-cli -h xxx.xxx.xxx.xxx dbsize

# 分析大 key
redis-cli -h xxx.xxx.xxx.xxx --bigkeys
```

list 的名称是 mylist，redis-benchmark 也会创建名称是 mylist 的 list，用于测试 list。我们的 redis-benchmark 命令大概是：

```shell
redis-benchmark -h xxx.xxx.xxx.xxx -c 2000 -n 1000000 -d 1000 -l
```

简单算一下，list 中 50 万个元素，每个 1000 Byte，`500000 * 1000/1024/1024 ≈ 477 M`。也就是随着测试不断进行，mylist 的元素不断增加，我猜是 mylist 生成的数据没被完全消化（pop 了一部分）。

另一个问题是，为何总是第一个节点重启？通过查看 mylist 可以知道，请求被重定向到了第一个节点。Redis Cluster 采用的是 Slot 来对数据进行分区，通过对 key 进行哈希运算得到存储的 Slot。`CLUSTER KEYSLOT <key>` 命令可以获得 key 被分配的 Slot。

```
127.0.0.1:6379> CLUSTER KEYSLOT mylist
(integer) 5282
```

mylist 被分配到了 5282 号 Slot，而 5282 位于第一个节点，因此导致该节点内存占用过多而 OOM。

### 解决方法

经过排查得知，是 mylist 中的元素未被清理导致 OOM，容器重启。最终，我们在每次 redis-benchmark 执行结束之后，再执行一次删除 mylist，问题得到解决，之后几天运行都很稳定，内存占用也比较正常。

### 参考

1. https://docs.redislabs.com/latest/ri/memory-optimizations/
2. https://redis.io/commands/info
3. https://redis.io/commands/cluster-keyslot