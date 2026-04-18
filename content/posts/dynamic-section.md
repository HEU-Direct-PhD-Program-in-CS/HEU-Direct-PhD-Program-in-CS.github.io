---
title: "动态链接机制-dynamic段"
date: 2026-04-16T22:30:00+08:00
description: "动态链接的dynamic段结构解析"
tags: ["post", "C语言", "动态链接"]
draft: true
type: post
weight: 25
showTableOfContents: true
lastmod: 2025-11-02
---

- 建议先对 PLT/GOT 机制有了解后继续阅读

## `.dynamic` 段

用于为动态链接器提供必要的元数据, 其结构可以在 `elf.h` 中找到:

```c
typedef struct
{
  Elf64_Sxword	d_tag;			/* Dynamic entry type */
  union
    {
      Elf64_Xword d_val;		/* Integer value */
      Elf64_Addr d_ptr;			/* Address value */
    } d_un;
} Elf64_Dyn;
```

在 .dynamic 段中,  `d_tag` 可选以下数值:

|名称|数值|`d_un`|可执行|共享目标|说明|
|:-:|:-:|:-:|:-:|:-:|:-:|
| `DT_NULL` | 0 | 忽略 | 必须 | 必须 | 标志 _DYNAMIC 数组末尾 |
| `DT_NEEDED` | 1 | `d_val` | 可选 | 可选 | 用于记录当前 `elf` 在被加载时需要被连同加载的 `.so` 对象的路径 |
