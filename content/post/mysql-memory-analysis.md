---
title: "MySQL 内存占用分析"
date: 2021-06-23
lastmod: 2021-06-23
draft: false
keywords: ["MySQL", "MySQL Memory", "MySQL 内存"]
description: "MySQL 内存占用分析，整理了分析方法。"
tags: ["MySQL"]
categories: ["MySQL"]
author: "Joe"

# You can also close(false) or open(true) something for this content.
# P.S. comment can only be closed
comment: true
toc: true
autoCollapseToc: false
# You can also define another contentCopyright. e.g. contentCopyright: "This is another copyright."
contentCopyright: <a rel="license noopener" href="https://creativecommons.org/licenses/by-nc-nd/4.0/deed.zh" target="_blank">CC BY-NC-ND 4.0</a>
---


在 MySQL 使用过程中，你一定出现过内存飙升、OOM、内存长期处于高位等内存异常现象。为了排查内存异常，我们需要分析内存占用情况，找出内存占用大户。下面整理了一些常用的内存分析方法。


<!--more-->


### 内存监控表 
我们可以从以下几张表中分析内存，每张表对应不同的维度，有用户维度、主机维度、进程维度。为了打开 `performance_schema` 功能，我们需要在 MySQL 配置中设置 `performance_schema = ON`。

```sql
mysql> show tables like '%memory%';
+-----------------------------------------+
| Tables_in_performance_schema (%memory%) |
+-----------------------------------------+
| memory_summary_by_account_by_event_name |
| memory_summary_by_host_by_event_name    |
| memory_summary_by_thread_by_event_name  |
| memory_summary_by_user_by_event_name    |
| memory_summary_global_by_event_name     |
+-----------------------------------------+
5 rows in set (0.00 sec)
```

### 查看 MySQL 总消耗内存

```sql
select * from sys.memory_global_total;
```

### 查看总体内存占用情况

利用排序便于查看
```sql
select event_name,CURRENT_NUMBER_OF_BYTES_USED/1024/1024 from performance_schema.memory_summary_global_by_event_name order by CURRENT_NUMBER_OF_BYTES_USED desc LIMIT 20;
```

示例：
```sql
mysql> select event_name,CURRENT_NUMBER_OF_BYTES_USED/1024/1024 from performance_schema.memory_summary_global_by_event_name order by CURRENT_NUMBER_OF_BYTES_USED desc LIMIT 20;
+-----------------------------------------------------------------------------+----------------------------------------+
| event_name                                                                  | CURRENT_NUMBER_OF_BYTES_USED/1024/1024 |
+-----------------------------------------------------------------------------+----------------------------------------+
| memory/innodb/buf_buf_pool                                                  |                          1045.00000000 |
| memory/group_rpl/GCS_XCom::xcom_cache                                       |                          1023.99899387 |
| memory/innodb/hash0hash                                                     |                            57.51127625 |
| memory/performance_schema/events_statements_summary_by_digest               |                            39.67285156 |
| memory/innodb/ut0link_buf                                                   |                            24.00006104 |
| memory/innodb/buf0dblwr                                                     |                            19.51831055 |
| memory/innodb/ut0new                                                        |                            16.07891273 |
| memory/performance_schema/events_statements_history_long                    |                            13.88549805 |
| memory/sql/TABLE                                                            |                            12.89442348 |
| memory/performance_schema/events_errors_summary_by_thread_by_error          |                            11.76171875 |
| memory/performance_schema/events_statements_summary_by_thread_by_event_name |                             9.79296875 |
| memory/performance_schema/events_statements_summary_by_digest.digest_text   |                             9.76562500 |
| memory/performance_schema/events_statements_history_long.digest_text        |                             9.76562500 |
| memory/performance_schema/events_statements_history_long.sql_text           |                             9.76562500 |
| memory/performance_schema/table_handles                                     |                             9.06250000 |
| memory/mysys/KEY_CACHE                                                      |                             8.00205994 |
| memory/performance_schema/memory_summary_by_thread_by_event_name            |                             7.91015625 |
| memory/innodb/sync0arr                                                      |                             6.25006866 |
| memory/performance_schema/events_errors_summary_by_host_by_error            |                             5.88085938 |
| memory/performance_schema/events_errors_summary_by_account_by_error         |                             5.88085938 |
+-----------------------------------------------------------------------------+----------------------------------------+
20 rows in set (0.00 sec)
```

### 查看线程内存占用情况
```sql
select thread_id,event_name,CURRENT_NUMBER_OF_BYTES_USED/1024/1024 from performance_schema.memory_summary_by_thread_by_event_name order by CURRENT_NUMBER_OF_BYTES_USED desc limit 20;

示例：
```sql
mysql> select thread_id,event_name,CURRENT_NUMBER_OF_BYTES_USED/1024/1024 from performance_schema.memory_summary_by_thread_by_event_name order by CURRENT_NUMBER_OF_BYTES_USED desc limit 30;
+-----------+---------------------------------------+----------------------------------------+
| thread_id | event_name                            | CURRENT_NUMBER_OF_BYTES_USED/1024/1024 |
+-----------+---------------------------------------+----------------------------------------+
|        53 | memory/sql/Gtid_set::Interval_chunk   |                            51.53873444 |
|        37 | memory/sql/thd::main_mem_root         |                             0.38488770 |
|         1 | memory/innodb/memory                  |                             0.30412292 |
|        55 | memory/innodb/trx0undo                |                             0.16213989 |
|        55 | memory/innodb/memory                  |                             0.15432739 |
|         1 | memory/mysqld_openssl/openssl_malloc  |                             0.13142014 |
|        37 | memory/innodb/memory                  |                             0.11706543 |
|        60 | memory/mysqld_openssl/openssl_malloc  |                             0.10986519 |
|      5462 | memory/innodb/memory                  |                             0.10468292 |
|         1 | memory/sql/NET::buff                  |                             0.06252670 |
|        52 | memory/mysqld_openssl/openssl_malloc  |                             0.06060410 |
|         1 | memory/innodb/ha_innodb               |                             0.03939533 |
|         1 | memory/mysys/TREE                     |                             0.03713226 |
|        27 | memory/innodb/trx0undo                |                             0.03054810 |
|        37 | memory/innodb/ha_innodb               |                             0.02210999 |
|      5462 | memory/innodb/ha_innodb               |                             0.02059937 |
|        53 | memory/innodb/memory                  |                             0.02039337 |
|      5462 | memory/sql/thd::main_mem_root         |                             0.01758575 |
|       341 | memory/sql/thd::main_mem_root         |                             0.01758575 |
|      5462 | memory/sql/Filesort_buffer::sort_keys |                             0.01590538 |
|        37 | memory/innodb/lexyy                   |                             0.01579475 |
|      5462 | memory/sql/String::value              |                             0.01564789 |
|       139 | memory/sql/String::value              |                             0.01563263 |
|       341 | memory/sql/String::value              |                             0.01563263 |
|        46 | memory/sql/NET::buff                  |                             0.01563168 |
|        53 | memory/sql/NET::buff                  |                             0.01563168 |
|        55 | memory/sql/NET::buff                  |                             0.01563168 |
|        55 | memory/sql/thd::main_mem_root         |                             0.01172638 |
|       139 | memory/sql/thd::main_mem_root         |                             0.01172638 |
|        37 | memory/innodb/trx0undo                |                             0.01107788 |
+-----------+---------------------------------------+----------------------------------------+
30 rows in set (0.01 sec)
```

### 疑点

从使用情况看，`select * from sys.memory_global_total;` 查询总体内存占用并不准确，与实际 mysql 进程占用内存相差较大。[MySQL 官方解释](https://bugs.mysql.com/bug.php?id=84174) 说 `sys.memory_global_total` 只会统计 MySQL 本身代码分配的内存，而一些库分配的内存则不会记录。

在我们持续压测 MySQL Group Replication 集群中，观察到 MySQL 内存占用一直在缓慢上升。尽管到达了 `innodb buffer` 的内存上限，依然还在上涨，就算没有请求了，内存也只是维持不变，并不会下降。看起来是哪里有内存泄露了，长此以往运行下去，必然会到某时刻 OOM。这时通过 performance_schema 也无法查出内存泄露的地方，只能通过其他方式了。

### 参考资料：

1. https://dev.mysql.com/doc/refman/8.0/en/memory-use.html
2. https://severalnines.com/database-blog/what-check-if-mysql-memory-utilisation-high
3. https://segmentfault.com/a/1190000030695421
4. https://dba.stackexchange.com/questions/62021/mysql-not-releasing-memory
5. http://hopehook.com/blog/mysql_oom
