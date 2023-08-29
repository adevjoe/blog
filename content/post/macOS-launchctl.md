---
title: macOS-launchctl
date: 2023-08-29
lastmod: 2023-08-29
draft: false
keywords: ["macOS", "launchctl", "systemd", "systemctl"]
description: "在 macOS 中开启守护进程"
tags: ["macOS", "launchctl"]
categories: ["macOS"]
author: "Joe"
toc: true
autoCollapseToc: false
contentCopyright: <a rel="license noopener" href="https://creativecommons.org/licenses/by-nc-nd/4.0/deed.zh" target="_blank">CC BY-NC-ND 4.0</a>
reward: false
mathjax: false
---

mac 使用 `launchctl` 来管理守护进程，类似于 `systemd`，服务的配置文件使用 `plist`。

<!--more-->

### 1. 制作服务配置文件

`plist` 示例：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.adevjoe.Demo</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/joe/path/to/app</string>
        <string>--arg</string>
        <string>xxx</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/Users/joe/com.adevjoe.Demo.err</string>
    <key>StandardOutPath</key>
    <string>/Users/joe/com.adevjoe.Demo.out</string>
</dict>
</plist>
```

ProgramArguments: 可以设置服务的二进制目录和参数

plist 目录：
```
~/Library/LaunchAgents  # 用户的进程
/Library/LaunchAgents   # 管理员设置的用户进程
/Library/LaunchDaemons  # 管理员提供的系统守护进程
/System/Library/LaunchAgents    # Mac操作系统提供的用户进程
/System/Library/LaunchDaemons   # Mac操作系统提供的系统守护进程
```

我们把配置好的 plist 文件放在 `~/Library/LaunchAgents` 目录即可。

### 2. 启动服务

```sh
launchctl load ~/Library/LaunchAgents/com.adevjoe.Demo.plist
```

启动后如果正常则不会有输出，也不会有错误信号。可以使用 `launchctl list | grep xxx` 来检测服务是否加载并启动。

### 3. 停止服务

```sh
# 停止服务，但服务还是会在下次重新登录或启动后运行
launchctl unload ~/Library/LaunchAgents/com.adevjoe.Demo.plist

# 停止并禁用服务，服务不会在下次重新登录或启动后运行
launchctl unload -w ~/Library/LaunchAgents/com.adevjoe.Demo.plist
```