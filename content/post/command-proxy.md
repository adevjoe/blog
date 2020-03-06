---
title: "命令行代理"
date: 2017-08-05
lastmod: 2017-08-05
draft: false
keywords: ["Linux", "proxy"]
description: "命令行代理"
tags: ["Linux", "proxy"]
categories: ["Tips"]
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


命令行如何优雅地科学上网？

推荐使用工具 polipo，将 socks 代理到 http，实现命令行科学上网。

<!--more-->

### 1. 安装

```shell
$ sudo apt-get install polipo
```

### 2. 修改配置文件

`vim ~/.polipo`

````
# polipo 使用的代理端口和地址
proxyAddress = "127.0.0.1"
proxyPort = 8123

allowedClients = 127.0.0.1
allowedPorts = 1-65535

# ss 代理配置
socksParentProxy = "127.0.0.1:1080"
socksProxyType = socks5
````
### 3. 启动

输入命令 `polipo`

没有输出就是好事，说明运行成功了

使用前需要添加环境变量
````shell
$ export http_proxy="http://127.0.0.1:8123"
$ export https_proxy="http://127.0.0.1:8123"
````

### 4. 测试

`curl www.google.com`

看见输出 google DOM 内容就说明成功了。

## 优化使用

每次使用输入环境变量极为不方便，最好是能够简化操作，还能实现在需要时才代理。

我的方案是在 `$HOME/.bashrc` 里面配置别名，使用 zsh 的也可以在 `$HOME/.zshrc` 里面配置。

配置如下:

```shell
alias proxy="export http_proxy='http://127.0.0.1:8123' export https_proxy='http://127.0.0.1:8123'"
```

这样以后每次需要代理时，先敲一个 `proxy` 就可以了，是不是贼方便。

[更多 linux 技巧](https://github.com/adevjoe/shell-tool)