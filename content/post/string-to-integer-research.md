---
title: "string to integer 算法优化"
date: 2018-12-04
lastmod: 2018-12-04
draft: false
keywords: ["atoi"]
description: "研究字符串转整形的算法与优化"
tags: ["atoi", "算法"]
categories: ["算法"]
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


<!-- Edit Replace Here.-->
在 leetcode 刷题过程中，刷到字符串转整形的算法，记录一下解决的方法和后续的一些优化。
字符串转整形是开发中经常遇到的，每个语言标准库基本都有实现。

<!--more-->
算法题的描述可以看 [这里](https://leetcode.com/problems/string-to-integer-atoi/)。

在第一次做这道题时，我按照描述，依次实现代码。第一个是想到将字符串转为 `byte`，
并按照规则识别每个字节。该实现过于冗长并复杂，调试几次后，终于通过了 leetcode 的测试。
提交如下，执行了 8ms
![string-to-integer-research-1](https://i.loli.net/2019/11/13/9Bj6g2SmqHihGEM.jpg)

代码如下:
```go
func myAtoi(str string) int {
	i := 0
	sign := 0 // 0 无符号 / 1 + / 2 -
	hasNum := false
	a := []byte(str)
	for _, value := range a {
		// 排除字母
		if value < 48 || value > 57 {
			if sign > 0 || hasNum {
				break
			}
			if value != 45 && value != 43 && value != 32 {
				break
			}
		}
		// 记录符号
		if i == 0 {
			if value == 43 {
				sign = 1
				continue
			}
			if value == 45 {
				sign = 2
				continue
			}
		}
		if b := isNumber(value); b != -1 {
			hasNum = true
			i = i*10 + b
			if i > math.MaxInt32 {
				break
			}
		}
	}
	if i > math.MaxInt32 {
		if sign == 2 {
			return math.MinInt32
		} else {
			return math.MaxInt32
		}
	}
	if sign == 2 {
		i = i - 2*i
	}
	return i
}

func isNumber(b byte) int {
	if b >= 48 && b <= 57 {
		return int(b) - 48
	}
	return -1
}
```

该实现虽然通过了，但执行效率只击败了 25% 的提交，而且代码结构自己看了也比较蛋疼。
今天分析了一下，决定重新实现一遍。
从描述中，我提取了四个关键点：

- 检测空白符，允许在符号和数字前出现
- 排除字母，一旦出现字符，即停止解析转化
- 记录符号，允许在数字之前出现一次符号，即 `-` 与 `+`
- 避免整形溢出

优化过的代码如下:
```go
func myAtoi(str string) int {
	num := 0
	sign := ""
	start := false // 一旦解析到数字或符号则为 true
	for key := range str {
		// 校验空白符
		if str[key:key+1] == " " && !start {
			continue
		}
		// 校验符号
		if (str[key:key+1] == "+" || str[key:key+1] == "-") && !start {
			start = true
			sign = str[key : key+1]
			continue
		}
		// 校验数字
		if str[key:key+1] >= "0" && str[key:key+1] <= "9" {
			// 检测溢出
			if num > math.MaxInt32/10 || (num == math.MaxInt32/10 && str[key:key+1] > "7") {
				if sign == "-" {
					return math.MinInt32
				}
				return math.MaxInt32
			}
			start = true
			num = num*10 + int(str[key]) - 48
			continue
		}
		// 不符合上述规则的直接结束
		break
	}
	if sign == "-" {
		num = -num
	}
	return num
}
```

优化过后的代码提交到 leetcode，整个测试用例执行时间缩短了一半，并击败了 100% 的 go 实现提交，
并且代码结构也得到简化。

该实现遍历规则有所改变，符合规则就继续遍历，不符合则直接 break，这将减少大量计算时间。
这和在平常编程中函数提前返回是相同的想法，能够简化逻辑，减少代码行数和嵌套次数。
