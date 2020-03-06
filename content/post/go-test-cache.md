---
title: "go test 缓存"
date: 2018-07-26
lastmod: 2018-07-26
draft: false
keywords: ["go", "go test", "go tool"]
description: "go test cache"
tags: ["go", "go test"]
categories: ["Golang"]
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


go 在 1.10 版本中引入了 go tool 的缓存，此功能会缓存 `go test`执行的结果。
每当执行 `go test` 时，如果功能代码和测试代码没有变动，则在下一次执行时，会直接读取缓存中的测试结果。
而且 `go test -v .` 和 `go test .`是分开缓存的。

<!--more-->

example:
```bash
// 第一次执行 go test -v .
$ go test -v .
=== RUN   TestUploadFile
--- PASS: TestUploadFile (6.99s)
PASS
ok      command-line-arguments  6.99s
```

测试正常执行。

```bash
// 第二次执行 go test -v .
$ go test -v .
=== RUN   TestUploadFile
--- PASS: TestUploadFile (6.99s)
PASS
ok      command-line-arguments  (cached)
```

缓存机制启动，测试秒完成，并使用了缓存的测试结果。

```bash
// 接着执行 go test .
$ go test .
ok      command-line-arguments  4.426s
```

没有走 `go test -v .` 的缓存，两个互相独立。

```bash
// 再次执行 go test .
$ go test .
ok      command-line-arguments  (cached)
```

缓存生效，没有显示执行时间，而是 `cached` 代替了。

正常情况下，我们是接受缓存的，只需要测试功能通过就行了。如果想跳过缓存，有什么办法呢？
大部分人都会想到会有参数控制的，那么这个参数就是 `-count=1`,把上面的测试命令加上参数，
`go test -count=1 -v .`，执行一下试试，果然可以跳过缓存。