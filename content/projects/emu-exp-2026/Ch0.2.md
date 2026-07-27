---
title: "Chapter 0x00.2 - 调试器"
type: page
weight: 2
draft: false
showTableOfContents: true
---

为了方便您后续的实验，本章介绍一些必要的 `emulator` 基础使用。

## 运行模式

从可执行文件直接 `riscv-emulator <PATH>` 运行程序。使用 cargo 从源码编译运行的时候则为 `cargo run --release -- <PATH> <OTHER-ARGS>`。使用 `--help` 查看完整参数。

键入 `ctrl + A` 后按下 `x` 可以强制退出模拟器。

## Debugger

`emulator` 提供了两种不同的 `debugger` 方式。

### 1. rvdb

`rvdb` 是模拟器内置的一个轻量级 `debugger`，使用 -g 或 --debug 启动选项进入 `rvdb`。 

`rvdb` 提供了一些实用的调试命令，下面简单列出一些，完整版请使用 `help`：

1. `help`： 查看帮助；
1. `print`(`p`)：打印寄存器、内存、csr、浮点/向量寄存器等；
1. `list`(`l`)：打印当前 `pc` 所在的指令，以及前后的反汇编代码；
1. `s`：步进；
1. `b`：断点；
1. `c`：继续运行，配合断点食用，可以给定最多的周期数；
1. `h`：查看最近退休的指令的历史记录；
1. `info`：查看 rvdb 信息，如断点，符号表；
1. `f-trace`：查看历史最近调用的函数（用于整体跟踪调用流）；

直接按回车会默认执行上一条调试语句。

### 2.GDB Server

使用 `-G` (`--gdb`) 参数来启用 gdb server (默认 TCP 端口 `1234`)。之后您可以在另一个终端会话使用 `riscv-unknown-elf-gdb` 的 remote 模式（`target remote :1234`），或使用 VSCode 的远程调试来链接到模拟器，来调试模拟器中运行的 riscv 程序了。

- rvdb 的 gdb 服务暂时不支持查看向量寄存器，如需调试 V 扩展指令，您可以为模拟器添加支持，或优先使用 `rvdb`
