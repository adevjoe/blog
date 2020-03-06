---
title: "我的 ArchLinux 安装配置"
date: 2018-03-22
lastmod: 2018-03-22
draft: false
keywords: ["ArchLinux", "Gnome", "Linux"]
description: "我的 ArchLinux 安装配置"
tags: ["ArchLinux", "Gnome", "Linux"]
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


现在使用 ArchLinux 作为主力开发机，体验了一把直接命令行安装系统，不得不说 ArchLinux 安装软件是真的方便，而且第三方编译的包也非常多。
这里列出一些我主要使用的软件和配置。

<!--more-->

### 桌面管理器

- xorg
- gnome
- gdm

```shell
# pacman -S gnome
# systemctl enable gdm.service
# systemctl start gdm.service
## 安装gnome shell 设置软件
# pacman -S gtk-theme-arc-git
```

### 输入法

- fcitx
- fcitx-sogoupinyin

```shell
$ sudo pacman -S noto-fonts-cjk
$ sudo pacman -S fcitx fcitx-im fcitx-sogoupinyin
```
修改 `/etc/profile` 文件，文件开头加上
```
export XMODIFIERS="@im=fcitx"
export GTK_IM_MODULE="fcitx"
export QT_IM_MODULE="fcitx"
```

### Theme

- gtk-theme-arc (主题)
- la-capitaine-icon-theme (图标)
- Breeze_cursors

```shell
$ sudo pacman -S gtk-theme-arc-git
$ yaourt -S la-capitaine-icon-theme-git
```

### Fonts

- Roboto Mono Medium for Powerline
- Fira Mono for Powerline

https://github.com/powerline/fonts

### GNOME Shell Extensions

- Coverflow Alt-Tab (Alt + Tab 3D 切换效果)
- Dash to Dock (类似于 MAC dock 程序栏)
- Simple net speed (显示网速)
- system-monitor (显示系统信息)
- Unite (合并菜单栏和顶部栏)
- User Themes (使用用户自定义主题)
- Web Search Dialog (网页搜索)

https://extensions.gnome.org/

### 贼好用的软件

- Chrome
- shadowsocks
- polipo
- dropbox 同步文件只用它
- Visual Studio Code
- jetbrains-toolbox 安装JB全家桶
- zeal 离线文档
- calibre 电子书制作神器
- synapse 桌面搜索

### 命令行软件

- terminator 终端
- zsh + ohmyzsh 比 bash 更好用的 shell
- screenfetch 命令行查看系统信息
- htop 系统情况查看，直接 pacman 安装
- autojump
- ffmpeg 下载 m3u8 转码到 mp4  `ffmpeg -i http://url.m3u8 "video.mp4"`

### 推荐 ArchLinux 安装教程

https://www.viseator.com/2017/05/17/arch_install/

[更多 linux 技巧](https://github.com/adevjoe/shell-tool)