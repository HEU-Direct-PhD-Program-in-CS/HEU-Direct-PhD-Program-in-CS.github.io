---
title: "Chapter 0x00.2 - 调试器"
type: page
weight: 2
draft: false
showTableOfContents: true
---

为了方便您后续的实验，本章介绍一些必要的 `emulator` 基础使用。

## Debugger

`emulator` 提供了两种不同的 `debugger` 方式。

### 1. rvdb

`rvdb` 是模拟器内置的一个轻量级 `debugger`，使用 -g 或 --debug 启动选项进入 `rvdb`。 

`rvdb` 提供了一些实用的调试命令，下面简单列出一些，完整版请使用 `help`：

1. `help`： 查看帮助；
2. `quit` 查看历史记录；
3. `s`：步进, `s 20` 表示继续 20 条指令；
4. `p`：打印寄存器、内存、csr、浮点/向量寄存器等；
5. `l`：打印当前 `pc` 所在的指令，以及前后的反汇编代码；
6. `info`：查看信息，如断点，符号表；
7. `b`：断点；
8. `c`：继续，配合断点食用；
9. `h`：查看最近退休的指令反汇编；
10. `f-trace`：查看历史最近调用的函数（用于整体跟踪调用流）；

直接按回车会默认执行上一条调试语句。

### 2.GDB Server

使用 `-G` (`--gdb`) 参数来启用 `gdb server `(端口: tcp 1234或其他自定义)。之后您可以在另一个终端会话启用 `riscv-unknown-elf-gdb` remote 模式 或使用 `vscode` 的远程调试来链接到模拟器，之后就能使用 `gdb` 来调试模拟器中运行的 riscv 程序了。

- gdb 目前还不支持查看向量寄存器，如需调试 SIMD 指令，您可以为模拟器添加 SIMD GDB 支持，或优先使用 `rvdb`
