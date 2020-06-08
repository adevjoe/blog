---
title: "Ansible 随想"
date: 2020-06-02
lastmod: 2020-06-02
draft: false
keywords: ["Ansible", "Cloud Native", "Auto ops", "IT Automation", "云原生", "自动化运维"]
description: "Kubernetes 中的声明式编程"
tags: ["Ansible", "Cloud Native", "Auto ops", "Operator"]
categories: ["Ansible"]
author: "Joe"

# You can also close(false) or open(true) something for this content.
# P.S. comment can only be closed
comment: true
toc: false
autoCollapseToc: false
# You can also define another contentCopyright. e.g. contentCopyright: "This is another copyright."
contentCopyright: <a rel="license noopener" href="https://creativecommons.org/licenses/by-nc-nd/4.0/deed.zh" target="_blank">CC BY-NC-ND 4.0</a>
reward: false
mathjax: false
---


最近接触到了 [Ansible](https://www.ansible.com/)，一个自动化运维的工具。官网这样介绍:

> Ansible is a radically simple IT automation platform that makes your applications and systems easier to deploy. Avoid writing scripts or custom code to deploy and update your applications — automate in a language that approaches plain English, using SSH, with no agents to install on remote systems.

大体来说就是 Ansible 能让我们部署应用更简单，避免写脚本去部署更新应用，一切过程用可读的配置来实现，通过 SSH 去安装，并且不用在目标机器上安装任何代理程序。

这篇文章不是 Ansible 教程，主要用来记录我在接触 Ansible 时的一些想法，也谈谈 Ansible 在 Kubernetes 中的应用场景。

<!--more-->

去年的时候，有个人问我他有 200 台机器，每台机器都运行相同的容器，需要一起启动和停止，可以怎么方便执行。我当时不知道有什么工具能做到这些，之前接触到的部署都是单机容器部署或者用 Kubernetes 调度。我只能回答说自己写个脚本来批量执行，然后也就不了了之了，也没有去搜索这样的工具。现在我觉得可以推荐用 Ansible 承担这个工作。

说起部署应用，回想一下以前都是怎么部署的，我的话大概分为五个阶段。第一阶段，在大学自学编程的时候，自己写的 java 程序和一些页面通过 ftp 上传到服务器，然后重启 tomcat来实现部署更新。当时更新频率低，且就一台机器，没觉得有啥不方便的，甚至因为第一次接触这些东西而感到有点厉害。第二阶段，开始参加工作了，写的是 PHP，PHP 是支持替换 .php 文件的，且不用重启应用。当时版本更新频繁，每天都更新几次，PHP 文件直接在物理机上，机器有好几台，然后用 [Capistrano](https://capistranorb.com/)来进行发布。第三阶段 ，开始用 Docker 了，技术栈切换到了 Golang，都是按 docker 镜像交付。部署用了阿里云的 Docker Swarm，在一段时间内，都是在控制台上修改镜像版本来实现更新部署。第四阶段，为了实现自动化，减少手动操作，搭建 Jenkins，并写了插件实现在 Jenkins 更新在阿里云 Docker Swarm 中的应用。第五阶段，开始使用 Kubernets，交付不再是镜像了，而是 Charts，安装则是通过 helm。

而如今的云原生产品生态中，很多应用会带一个 operator，用来部署管理应用的生命周期，例如 [prometheus-operator](https://github.com/coreos/prometheus-operator)。operator 会创建 CRD 用来定义应用，每当你创建或更新这个 CR，operator 监听并部署管理应用。如下图所示:

![ansible-in-cloud-native-1](https://i.loli.net/2020/06/08/7ycTAhlPXYGbkgj.jpg)

在了解 Ansible 的时候，我一边想到它作为运维自动化工具的强大，一边也会想在 Kubernetes 中，还会用到 Ansible 吗。Jeff Geerling 的这篇[文章](https://www.ansible.com/blog/how-useful-is-ansible-in-a-cloud-native-kubernetes-environment)给了我们解答。

在云原生场景下，Ansible 主要作用在三个方面，容器构建、集群管理、应用生命周期管理。

#### 容器构建
我们在构建容器镜像一般是写 Dockerfile，把依赖安装等命令脚本写在 Dockerfile 里面，然后使用 docker build 命令构建镜像。Ansible 使用 [Buildah](https://buildah.io/) 和 [ansible-bender](https://github.com/ansible-community/ansible-bender) 这样的工具构建镜像，不用安装 Docker，然后使用 Playbooks 描述构建镜像需要的依赖和步骤。这样的语法比 Dockerfile 更易于阅读和维护。

例如:

```yaml
---
- name: Demonstration of ansible-bender functionality
  hosts: all
  vars:
    ansible_bender:
      base_image: python:3-alpine

      working_container:
        volumes:
          - '{{ playbook_dir }}:/src'

      target_image:
        name: a-very-nice-image
        working_dir: /src
        labels:
          built-by: '{{ ansible_user }}'
        environment:
          FILE_TO_PROCESS: README.md
  tasks:
  - name: Run a sample command
    command: 'ls -lha /src'
  - name: Stat a file
    stat:
      path: "{{ lookup('env','FILE_TO_PROCESS') }}"
```

#### 集群管理
Ansible 使用 [Kubespray](https://kubespray.io/) 这样的工具来搭建 Kubernetes 集群，可以维护多套集群。老实说，没太了解这个使用场景。

#### 应用生命周期管理

Ansible 可以使用 [Operator SDK](https://github.com/operator-framework/operator-sdk) 来管理 Kubernetes 中应用的生命周期，包括安装、升级、备份等操作，而且不用写 Go 的代码，直接通过 Playbook 来描述产品部署的逻辑。在 operator 工具链中，我们还可以可视化安装升级应用。如下图所示，operator-hub 可以展示可用于安装的应用。
![ansible-in-cloud-native-2](https://i.loli.net/2020/06/08/3TU7wZSvoJdOczY.jpg)
之前提到的 prometheus-operator，也可以用 ansible 实现，但是很多逻辑感觉不用代码很难表现出来，用 playbook只能做一些简单的逻辑。对于 operator-sdk，我建议还是用 go 来实现相关逻辑更靠谱一点，但是如果你的团队对 ansible 很熟练并且 operator 的逻辑不复杂的话，我觉得还是可以用的。

#### 总结
Ansible 是一个强大的自动化运维工具，在多台机器上安装进程型的程序，用 Ansible 可以很方便。但是在云原生场景下，我认为 ansible 可以施展的空间不大。从个人来看这个工具还是很值得了解的，不管是为了使用还是了解它的部署思想。