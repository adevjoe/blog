---
title: "Linux 密钥登录"
date: 2017-08-06
lastmod: 2017-08-06
draft: false
keywords: ["Linux", "SSH"]
description: "Linux 密钥登录"
tags: ["SSH", "Linux"]
categories: ["Linux"]
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


登录 linux 每次输入密码很麻烦，并且不安全，这种情况下我们可以使用秘钥登录。

<!--more-->

流程:

1. 进入当前用户的 home 目录, `cd ~/.ssh`

2. 添加自己的公钥, `vi authorized_keys` 把自己的id_rsa.pub里面的内容复制进去

3. 确保权限正确
```shell
$ chmod 700 ~/.ssh
$ chmod 600 ~/.ssh/authorized_keys
```

4. 检查是否开通秘钥登录 `vi /etc/ssh/sshd_config` 确认以下设置正确    
````
RSAAuthentication ye
PubkeyAuthentication yes
````

5. 重启 ssh
```shell
$ systemctl restart sshd
```

确认秘钥设置成功后，可以把 `PasswordAuthentication` 设置为 `no` ,禁止密码登录。
