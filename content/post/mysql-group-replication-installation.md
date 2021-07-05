---
title: "MySQL Group Replication 部署"
date: 2021-07-05T11:02:21+08:00
lastmod: 2021-07-05T11:50:21+08:00
draft: false
keywords: ["MySQL", "MGR", "Group Replication", "MySQL Shell"]
description: "MySQL Group Replication 部署，借助于 MySQL Shell"
tags: ["MySQL", "MGR", "Group Replication", "MySQL Shell"]
categories: ["MySQL"]
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

MySQL Group Replication 是 MySQL 的一种高可用解决方案。在 MGR 出现之前，高可用主要通过异步复制和半同步复制来实现，有了主从复制就一定程度上避免了单点故障。但是主从复制解决不了数据一致性、自动故障恢复等问题，同时维护比较复杂，只能借助一大堆工具或脚本来解决。MGR 的出现解决了数据一致性问题，同时内置了故障自动恢复。在 8.0 中，借助 MySQL InnoDB Cluster 框架，MGR 部署维护变得前所未有地简单。



<!--more-->

 

### 部署工具

下面，我们通过 [MySQL Shell](https://dev.mysql.com/doc/mysql-shell/8.0/en/) 来部署 MGR，版本为 `8.0.25`。如果想尝试手动部署 MGR，可以参考 [MySQL 官方文档](https://dev.mysql.com/doc/refman/8.0/en/group-replication-deploying-in-single-primary-mode.html)。但我还是建议使用 MySQL Shell，因为真的很方便，几条命令就能部署起来一个集群。使用 MySQL Shell 部署 MGR，主要用到 `dba` 这个对象中的方法。它的所有方法如下图所示：

![mysql-shell-dba-method](https://images.adevjoe.com/2021-07-05-hEy4wh.png)

在这次部署集群的示例中，我们只需要 `createCluster` 和 `addInstance` 和方法，分别是创建集群和往集群添加实例。MySQL Shell 中可以用 `Python` 或 `JavaScript` 语法来执行这些方法，默认是 `JavaScript` 语法，下面我们也用 `JavaScript` 来举例。



### 部署文件

我准备了一个 `docker-compose` 文件来简单编排一下 mgr 集群实例，可以从 [mgr-simple](https://github.com/adevjoe/mgr-simple) 获取。MGR 启动需要开启一些参数，在 `docker-compose.yaml` 中的 command 可以看到。这个示例中使用的是 3 节点单主架构。

```
binlog_transaction_dependency_tracking=WRITESET
enforce_gtid_consistency=ON --gtid_mode=ON
slave_parallel_type=LOGICAL_CLOCK
slave_preserve_commit_order=ON
```

因为 MySQL 8.0 默认密码验证插件改了，为了兼容 5.x 版本的客户端，所以这里设置了一下 `default-authentication-plugin=mysql_native_password`。

### 启动实例

在 `docker-compose.yaml` 相同目录中执行 `docker-compose up -d` 启动三个实例。

```shell
$ docker-compose up -d
Creating network "mgr-simple_default" with the default driver
Pulling db-1 (mysql/mysql-server:8.0.25)...
8.0.25: Pulling from mysql/mysql-server
Digest: sha256:56ec3d7509327c66e4b8b22c72ecd56572ae1f87c91ef806c80fa09c7707c845
Status: Downloaded newer image for mysql/mysql-server:8.0.25
Creating mgr-simple_db-1_1 ... done
Creating mgr-simple_db-3_1 ... done
Creating mgr-simple_db-2_1 ... done
```

待容器创建完成后，执行 `docker ps | grep mysql/mysql-server` 查看刚才创建的容器。

```shell
$ docker ps | grep mysql/mysql-server
28923e9bd584   mysql/mysql-server:8.0.25   "/entrypoint.sh --de…"   13 minutes ago   Up 13 minutes (healthy)   33060-33061/tcp, 0.0.0.0:33061->3306/tcp, :::33061->3306/tcp   mgr-simple_db-1_1
ee9d0e4f0a0c   mysql/mysql-server:8.0.25   "/entrypoint.sh --de…"   13 minutes ago   Up 13 minutes (healthy)   33060-33061/tcp, 0.0.0.0:33062->3306/tcp, :::33062->3306/tcp   mgr-simple_db-2_1
4c28a75baf2b   mysql/mysql-server:8.0.25   "/entrypoint.sh --de…"   13 minutes ago   Up 13 minutes (healthy)   33060-33061/tcp, 0.0.0.0:33063->3306/tcp, :::33063->3306/tcp   mgr-simple_db-3_1
```

### 创建集群

登录其中一个上一步创建的容器中，在容器中进入到 MySQL Shell 环境，`docker exec -it container_id bash`。`container_id` 为上一步获取的容器 ID。MySQL Shell 进入的命令为 `mysqlsh --uri user:password@ip:port`，该示例中，我们密码是 `123`，同时在 `docker-compose.yaml` 中指定了 `hostname`，所以我们可以用 `db-1` 代替 ip。

```shell
$ docker exec -it 28923e9bd584 bash
bash-4.4# mysqlsh --uri root:123@db-1:3306
Cannot set LC_ALL to locale en_US.UTF-8: No such file or directory
MySQL Shell 8.0.25

Copyright (c) 2016, 2021, Oracle and/or its affiliates.
Oracle is a registered trademark of Oracle Corporation and/or its affiliates.
Other names may be trademarks of their respective owners.

Type '\help' or '\?' for help; '\quit' to exit.
WARNING: Using a password on the command line interface can be insecure.
Creating a session to 'root@db-1:3306'
Fetching schema names for autocompletion... Press ^C to stop.
Your MySQL connection id is 47
Server version: 8.0.25 MySQL Community Server - GPL
No default schema selected; type \use <schema> to set one.
 MySQL  db-1:3306 ssl  JS >
```

上面说到，MySQL Shell 默认的语法是 JS，所以我们输入的命令都是驼峰格式。退出 shell 可以用 `\quit` 或 `\q`，进入 `sql` 环境可以用 `\sql`，返回到 API 环境中可以用 `\js` 或 `\py`。

进入到了 MySQL Shell，我们就可以创建集群了，命令为 `dba.createCluster('Cluster')`，必选参数为集群名称，可选参数是一个字典类型，很多其他命令也都类似，在最后一个参数中可以填可选参数，具体每个命令的可选参数可以查看文档。

不得不说这个彩色命令行真的很加分，看起来非常舒服。

![](https://images.adevjoe.com/2021-07-05-gSBfqk.png)

从提示中，可以看到集群已经创建成功了，此时集群中只有一个节点，集群至少需要 3 个节点才能高可用，容忍一个节点异常。

这时我们可以使用 `dba.getCluster().status()` 查看集群状态了，可以发现集群中只有一个节点。

```shell
> dba.getCluster().status()
{
    "clusterName": "Cluster",
    "defaultReplicaSet": {
        "name": "default",
        "primary": "db-1:3306",
        "ssl": "REQUIRED",
        "status": "OK_NO_TOLERANCE",
        "statusText": "Cluster is NOT tolerant to any failures.",
        "topology": {
            "db-1:3306": {
                "address": "db-1:3306",
                "memberRole": "PRIMARY",
                "mode": "R/W",
                "readReplicas": {},
                "replicationLag": null,
                "role": "HA",
                "status": "ONLINE",
                "version": "8.0.25"
            }
        },
        "topologyMode": "Single-Primary"
    },
    "groupInformationSourceMember": "db-1:3306"
}
```

### 添加节点

接着，我们把其他两个节点加入到集群中，使用 `addInstance` 方法，同时我们指定数据同步的方式为 `clone`，意为全量复制，集群重新恢复并加入到集群后，会全量同步集群中的数据到该节点中。数据恢复的方式还有增量这种方式，我们可以根据不同情况使用。

```shell
dba.getCluster().addInstance('root:123@db-2:3306', {'recoveryMethod': 'clone'})
dba.getCluster().addInstance('root:123@db-3:3306', {'recoveryMethod': 'clone'})
```

添加完其他两个节点后，再来查看一下集群状态，3 个节点都出现了，集群状态正常。

```shell
> dba.getCluster().status()
{
    "clusterName": "Cluster",
    "defaultReplicaSet": {
        "name": "default",
        "primary": "db-1:3306",
        "ssl": "REQUIRED",
        "status": "OK",
        "statusText": "Cluster is ONLINE and can tolerate up to ONE failure.",
        "topology": {
            "db-1:3306": {
                "address": "db-1:3306",
                "memberRole": "PRIMARY",
                "mode": "R/W",
                "readReplicas": {},
                "replicationLag": null,
                "role": "HA",
                "status": "ONLINE",
                "version": "8.0.25"
            },
            "db-2:3306": {
                "address": "db-2:3306",
                "memberRole": "SECONDARY",
                "mode": "R/O",
                "readReplicas": {},
                "replicationLag": null,
                "role": "HA",
                "status": "ONLINE",
                "version": "8.0.25"
            },
            "db-3:3306": {
                "address": "db-3:3306",
                "memberRole": "SECONDARY",
                "mode": "R/O",
                "readReplicas": {},
                "replicationLag": null,
                "role": "HA",
                "status": "ONLINE",
                "version": "8.0.25"
            }
        },
        "topologyMode": "Single-Primary"
    },
    "groupInformationSourceMember": "db-1:3306"
}
```

### 卸载

在 `docker-compose.yaml` 相同目录中执行 `docker-compose down`。

### 小结

至此，MGR 集群就部署完成了，借助 MySQL Shell，极大便利了 MGR 的运维，创建集群只需要简单的几个命令。这也是 MySQL 高可用发展的一个趋势。除了部署，使用 MySQL Shell 还可以很多玩法来管理 MGR 集群。

### 参考资料

- https://dev.mysql.com/doc/refman/8.0/en/group-replication.html
- https://dev.mysql.com/doc/dev/mysqlsh-api-javascript/8.0/
- [Everything You Need to Know About MySQL Group Replication](https://www.youtube.com/watch?v=IfZK-Up03Mw)
