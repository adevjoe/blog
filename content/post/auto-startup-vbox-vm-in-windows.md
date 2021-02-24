---
title: "在 Windows 10 中配置 VirtualBox 虚拟机自启动"
date: 2020-08-25
lastmod: 2020-08-25
draft: false
keywords: ["Startup", "VirtualBox", "VM"]
description: "在 Windows 10 中配置 VirtualBox 虚拟机自启动"
tags: ["VirtualBox"]
categories: ["VirtualBox"]
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

在 Windows 10 中配置 VirtualBox 虚拟机自启动。

<!--more-->

环境:

- Windows 10 Pro 1909
- VirtualBox 6.1.2

思路: 通过快捷方式实现在 Windows 中开机自启动。

### 创建桌面快捷方式

![auto-startup-vbox-vm-in-windows-1](https://images.adevjoe.com/ansible-in-cloud-native-1.jpg)

### 更改桌面快捷方式命令

默认创建出来的快捷方式是界面形式启动虚拟机，如果要使用无界面启动，需要修改快捷方式执行的命令。

![auto-startup-vbox-vm-in-windows-2](https://images.adevjoe.com/ansible-in-cloud-native-2.jpg)

VirtualBox 路径根据真实情况修改。

#### 无界面式启动
```
"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" startvm {vm_name} --type headless
```

使用该模式启动，会在启动时闪过一个命令窗口，不必惊慌。

#### 有界面式启动

```
"C:\Program Files\Oracle\VirtualBox\VirtualBoxVM.exe" --comment "{vm_name}" --startvm "{uuid}"
```


### 配置开机自启动

把快捷方式放到 `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp` 目录就行。

