---
title: "一次 Redis Benchmark 节点超时排查"
date: 2021-09-04T20:56:02+08:00
lastmod: 2021-09-04T20:56:02+08:00
draft: false
keywords: ["Redis Benchmark", "timeout"]
description: "Redis benchmark timeout trouble-shooting"
tags: ["redis-benchmark", "Redis"]
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

<!-- Abstract -->
最近在使用 `redis-benchmark` 测试时，发现偶尔连接超时。这个问题让人匪夷所思，因为所有 `Redis ` 服务都是正常的，在测试的过程中，也没有出现重启现象，主从切换也没有发生。这里记录一下问题排查的过程。



<!--more-->



<!-- Content -->
### 背景
先说一下 `Redis` 运行的环境，我搭建的是一套 Redis 集群，运行在 k8s 中。Redis 3 主 3 从分布在 3 个 `StatefulSet` 中，连接用的 `Service`，绑定对象为这 6 个 `Pod`。在使用 `redis-benchmark` 测试的时候，就是用的 `Service` 的 IP 来连接的。

`redis-benchmark` 报错：

```
bash-5.1# redis-benchmark -h 10.4.119.162 -p 6379 -c 50 --cluster -n 1000000 -r 1000000 -d 512 --threads 8  --csv -t set,incr,hset
Cluster has 3 master nodes:

Master 0: 2c424d84214aa03cf402c9a886dd8a1d1487a344 10.3.0.115:6379
Master 1: c54420c20d70268b2973157690173bf6e46d2640 10.4.119.162:6379
Master 2: bf13c68f55e848f40c68a0f833470fdc6cda8f03 10.3.0.113:6379

Could not connect to Redis at 10.3.0.113:6379: Operation timed out
WARN: could not fetch node CONFIG 10.3.0.113:6379
```

### 排查过程
首先排查了 `Redis` 本身的服务状态，发现服务都正常。然后多执行了几遍，复现一下问题，也总结了一些规律。

在多次执行后，发现有时 nodes 列表中有 service 的 ip，这种情况下，很大概率失败。比如上面的执行记录，用的 service 的 ip 为 `10.4.119.162`，按理来说，nodes 列表里面不应该有这个 ip 的。在使用 `cluster nodes` 执行多遍过后，也是正常的。那么为什么会出现 `service` 的 ip 呢？随即我翻了一下 `redis-benchmark` 的源码，在其中发现 `redis-benchmark` 执行的时候会获取节点的 master ip，如果 `redis-benchmark` 的 `host` 参数和 master ip 列表里面的某个 ip 一致，则使用 host 的信息。也就是 `redis-benchmark` 打印的 master ip 可能会包含 service 的 ip。下面就是这段逻辑的代码。我使用的 `redis 6.0.9` 的版本，这个版本的实现会有这个问题，在最新的版本中，已经被 [#8154](https://github.com/redis/redis/pull/8154) 修复了。

```c
static int fetchClusterConfiguration() {
    int success = 1;
    redisContext *ctx = NULL;
    redisReply *reply =  NULL;
    ctx = getRedisContext(config.hostip, config.hostport, config.hostsocket);
    if (ctx == NULL) {
        exit(1);
    }
    // 根据当前 ip 创建第一个节点
    clusterNode *firstNode = createClusterNode((char *) config.hostip,
                                               config.hostport);
    if (!firstNode) {success = 0; goto cleanup;}
    reply = redisCommand(ctx, "CLUSTER NODES");
    // ... 省略
    while ((p = strstr(lines, "\n")) != NULL) {
        *p = '\0';
        line = lines;
        lines = p + 1;
        char *name = NULL, *addr = NULL, *flags = NULL, *master_id = NULL;
        // ... 省略
        int myself = (strstr(flags, "myself") != NULL);
        int is_replica = (strstr(flags, "slave") != NULL ||
                         (master_id != NULL && master_id[0] != '-'));
        // 如果是从节点，则返回
        if (is_replica) continue;
        if (addr == NULL) {
            fprintf(stderr, "Invalid CLUSTER NODES reply: missing addr.\n");
            success = 0;
            goto cleanup;
        }
        // 初始化节点
        clusterNode *node = NULL;
        // ... 省略
        
        // 如果当前节点 ip 和 -h 设置的 ip 一致，就直接用前面创建的 firstNode 作为节点信息
        if (myself) {
            node = firstNode;
            // 旧的实现
            if (node->ip == NULL && ip != NULL) {
                node->ip = ip;
            // 新的实现
            if (ip != NULL && strcmp(node->ip, ip) != 0) {
                node->ip = sdsnew(ip);
                node->port = port;
            }
        } else {
            node = createClusterNode(sdsnew(ip), port);
        }
        // ... 省略
      
        // 添加节点至 master 节点列表中
      	if (!addClusterNode(node)) {
            success = 0;
            goto cleanup;
        }
    }
}
```

但是为什么这个情况是随机的呢？我想到的是，在访问 `Service` 时，它会随机地把流量转发到对应的 `Pod` 中。如果把请求转发到了某一个主节点，那么它获取的节点列表，就会包含 `Service` 的 IP，在接下来执行性能测试的请求中，都会使用这个 IP。在多次请求后，`Service` 的请求转发会和之前不同，那么这种情况下，就会发生连接超时了。在 `Service` 中有个会话保持的功能，目的就是一个会话中，转发的 Pod IP 不会变化，可以通过 `sessionAffinity` 开启。`sessionAffinity: None` 则是不开启，`sessionAffinity: ClientIP` 则是基于客户端 IP 做回话保持。

```yaml
kind: Service
apiVersion: v1
metadata:
  name: redis-cluster-demo
  namespace: redis
  labels:
    redis/name: redis-cluster-demo
spec:
  ports:
    - name: tcp-6379-6379
      protocol: TCP
      port: 6379
      targetPort: 6379
  selector:
    redis/name: redis-cluster-demo
  clusterIP: 10.4.119.162
  type: ClusterIP
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800

```

设置会话保持后，问题没有再出现了。针对于这个问题，可以通过设置 Service 的 `sessionAffinity` 来解决，也可以通过升级 `redis-benchmark` 的版本来解决。
