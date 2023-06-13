---
title: "WASM On Kubernetes"
date: 2023-06-14
lastmod: 2023-06-14
draft: false
keywords: ["WebAssembly", "WASM", "WASI", "Kubernetes"]
description: "在 Kubernetes 中运行 WASM 程序"
tags: ["WebAssembly", "WASM", "WASI", "Kubernetes"]
categories: ["WebAssembly", "Kubernetes"]
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

WebAssembly (Wasm) 是一种针对沙箱环境设计的编译目标，允许在任何地方运行任何代码。它为在开发团队间共享代码提供了一个标准接口，还可实现多种编程语言之间的互操作性。不过，除了前端应用程序，Wasm 还有一个主要用途：容器。

通过将 Wasm 与容器结合并在 Kubernetes 中运行，我们可以创建与传统容器相比速度更快、内存占用更小、更安全的沙箱环境。这对于在边缘节点上进行部署尤为有益。在本文中，我们将演示如何在 Kubernetes 中运行一个 Wasm 应用程序。

## 准备工作

为了创建一个 Wasm 应用程序，我们首先需要一个编译为 Wasm 的程序，参考 [wasmdemo](https://github.com/adevjoe/wasmdemo/tree/main/go)。我们可以使用 Rust 或 Go 进行编译。在我们的示例中，我们使用 Go 1.21 编译 Wasm：

```bash
GOOS=wasip1 GOARCH=wasm gotip build -o main.wasm main.go
```

**注意：** 目前，官方的 Go 编译器 (golang/go) 还不支持直接编译 Wasi。详见 [#31105](https://github.com/golang/go/issues/31105)。

或者使用 [tinygo](https://tinygo.org/) 来编译 wasm 文件，如 `tinygo build -target=wasi -o main.wasm main.go`。

编译好 wasm 后，我们可以使用运行时来运行 wasm 程序，如果安装了 [wasmtime](https://wasmtime.dev/)，可以执行如下命令运行。

```bash
wasmtime main.wasm
```

如果需要 rust 版本的，可以通过 [这里](https://github.com/adevjoe/wasmdemo/tree/main/rust) 查看。

### 使用 Docker

接下来，我们可以使用 [Docker](https://www.docker.com/) 或 [Containerd](https://containerd.io/) 来构建我们的 Wasi 容器。

首先，我们需要一个 `Dockerfile`，如下所见，和一个普通的 Dockerfile 并没有什么差别：

```Dockerfile
FROM scratch
ADD main.wasm /
CMD ["/main.wasm"]
```

现在，我们可以使用以下命令构建我们的 Wasm 容器：

```bash
docker build -t wasmdemo .
```

### 运行 wasm 容器

我们可以用 Docker 运行容器，也可以用 containerd 运行容器。两者都需要支持 wasm 运行时。

Docker:
```bash
docker run --rm --name=wasmdemo --runtime=io.containerd.wasmedge.v1 --platform=wasi/wasm32 ghcr.io/adevjoe/wasmdemo:1.0
```

Containerd:
```bash
sudo ctr i pull ghcr.io/adevjoe/wasmdemo:1.0
sudo ctr run --rm --runtime=io.containerd.wasmedge.v1 ghcr.io/adevjoe/wasmdemo:1.0 wasmdemo
```


## 在 Kubernetes 中运行 Wasm

现在，我们准备在 Kubernetes 中运行我们的 Wasm 应用程序。首先，我们需要一个 [Kubernetes in Docker (Kind)](https://kind.sigs.k8s.io/) 集群，使用以下 `wasm.yaml` 文件创建：

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  image: ghcr.io/adevjoe/kind-wasm:v1.24.12
- role: worker
  image: ghcr.io/adevjoe/kind-wasm:v1.24.12
```

如何构建一个可以运行 wasm 的节点镜像，可以参考 [Dockerfile](https://raw.githubusercontent.com/adevjoe/wasmdemo/main/kind/node/Dockerfile)。

创建一个 Kind 集群：

```bash
kind create cluster --config=wasm.yaml --name=wasm
```

接下来，我们需要创建一个 RuntimeClass 资源，指示我们的 Wasm 容器在 Kubernetes 中的运行时配置：

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: wasm
handler: wasm
```

保存此文件为 `runtime-class.yaml`，并使用 `kubectl` 将其应用到集群：

```bash
kubectl apply -f runtime-class.yaml
```

最后，我们需要创建一个 Job 资源，用于运行我们的 Wasm 应用程序：

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: wasmdemo
spec:
  template:
    spec:
      runtimeClassName: wasm
      containers:
        - image: ghcr.io/adevjoe/wasmdemo:1.0
          imagePullPolicy: Always
          name: wasmdemo
      restartPolicy: Never
  backoffLimit: 1
```

保存此文件为 `job.yaml`，并使用 `kubectl` 将其应用到集群：

```bash
kubectl apply -f job.yaml
```

现在，我们应该能够查看到一个正在运行的 Wasm 容器。可以通过查看日志来验证：

```bash
kubectl logs job/wasmdemo
```

到这里，我们已经成功地在 Kubernetes 中运行了一个容器驱动的 Wasm 应用程序。我们可以使用 Wasm 在 Kubernetes 中实现更快速、更安全和更轻量级的运行时环境，尤其是在边缘计算场景中。这有助于减少资源消耗，提高部署应用程序的效率。
