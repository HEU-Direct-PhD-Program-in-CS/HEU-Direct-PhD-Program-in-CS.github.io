---
title: "Chapter 0x01 - 裸机程序"
type: page
weight: 10
draft: false
showTableOfContents: true
---

## 本章概览

本章从“怎样为没有操作系统的机器编写程序”开始，接触到 RISC-V 汇编、ABI、ELF 和链接脚本：编译器按照 ABI 生成目标文件，链接器为代码和数据安排地址，模拟器加载最终的 ELF，启动代码再把控制权交给 `main`。最终任务是移植一个自选程序。

## 从源码到 ELF

裸机程序从源码到执行大致经过下面的过程：

```text
C / Assembly
     │  编译、汇编
     ▼
Relocatable Object Files（.o，ELF 格式）
     │  链接，由 linker.ld 决定地址和 section 布局
     ▼
Executable ELF
     │  emulator 将其中的可加载段载入 RAM
     ▼
_start
```

编译器和汇编器生成若干目标文件，链接器合并所有目标文件——解析函数和全局变量的引用，并按照 linker script 生成具有最终地址的可执行目标文件。RISC-V Emulator 会根据 ELF 中的可加载段把内容写入 RAM。

本项目中的 CPU 初始 PC 默认是 `0x8000_0000`，因此 linker script 会把启动代码安排到这个位置。

## 极简 RISC-V 汇编导读

GNU ASM 汇编文件通常由 label、指令和 assembler directive（伪指令）组成：

```asm
.section .text.ENTRY
.globl _start

_start:
1:
    la a0, msg             # 设置第一个参数为 msg 的地址
    call print             # 函数调用
    j 1b                   # 跳回 (back) 最近的 label 1
.section .rodata
msg:
    .asciz "Hello, world!"
```

`_start:` 和 `msg:` 是标号（label），代表当前位置的地址。`la`、`call` 和 `j` 是 RISC-V 汇编指令或伪指令（pseudo instruction）。以 `.` 开头的行通常是汇编器伪指令（directive），由汇编器处理，本身并不是 CPU 的指令。

数字标号适合在一小段汇编中重复使用。`1f` 表示向前（forward）寻找下一个 `1:`，`1b` 表示向后（back）寻找最近的 `1:`；`boot.S` 中就使用了这种写法。

ABI 约定解释了函数之间如何配合：参数和返回值放在哪些寄存器，哪些寄存器需要跨调用保存，栈指针如何移动，返回地址怎样传递。C 与汇编混合调用、函数返回到错误位置或栈内容异常时，都可以沿着这些约定检查。

RISC-V 的寄存器名字简洁易懂：

- `zero` 始终读出零；`ra` 是返回地址；`sp` 是栈指针。
- `a0`～`a7` 用于函数参数和返回值。
- `t0`～`t6` 是临时寄存器，函数调用后内容可以改变（调用者保存）。
- `s0`～`s11` 是保存寄存器，使用它们的函数在退出前要恢复原值（被调用者保存）。

`li`、`la`、`mv`、`call` 和 `ret` 等伪指令让汇编更容易阅读，这些指令并不存在于真实处理器上，而是由汇编器根据操作数把它们展开成一条或多条真实指令。

TODO: 解释 directive 和 ELF section

## Linker Script

linker script 描述目标文件中的 section 怎样组成最终 ELF，以及它们在地址空间中放在哪里。`test_resources/linker.ld` 的核心结构可以简化为：

```ld
SECTIONS {
    . = 0x80000000;

    .text : {
        *(.text.ENTRY)
        *(.text .text.*)
    }

    .rodata : { *(.rodata .rodata.*) }
    .data   : { *(.data .data.*) }
    .bss    : { *(.bss .bss.*) }
    .stack  : { *(.stack) }
}
```

其中：

- `.` 是 location counter，表示当前输出地址；把它设为 `0x8000_0000`，后续 section 就从 Virt Board 的 RAM 起始位置排列。
- `.text : { ... }` 定义一个输出 section；`*(.text .text.*)` 收集所有输入目标文件中匹配的 section。
- `*(.text.ENTRY)` 写在普通 `.text` 前面，因此 `boot.S` 中的启动入口会优先放置。
- `ALIGN(...)` 按照对齐要求推进 location counter。

linker script 负责 ELF 的布局，不负责执行初始化。例如，它可以为 `.bss` 和 `.stack` 安排空间并导出边界符号，真正设置 `sp`、清零内存或调用 `main` 的仍然是启动代码。

你可能会需要下面几个命令来不同角度检查最终 ELF：

```bash
riscv64-unknown-elf-readelf -S bin/main.elf
riscv64-unknown-elf-nm -n bin/main.elf
riscv64-unknown-elf-objdump -d -M no-aliases bin/main.elf
```

把这些结果与 linker script 和 rvdb 中看到的地址对照起来，就能看到 section、符号和运行时内存之间的对应关系。

## MMIO

本章你可能会使用的内存区域如下：

| 区域 | 基地址 | 用途 |
| --- | --- | --- |
| power manager | `0x0010_0000` | 结束模拟器运行 |
| UART | `0x1000_0000` | 终端输入输出 |
| CLINT | `0x0200_0000` | 定时器与软件中断（mtime / mtimecmp） |
| RAM | `0x8000_0000` | ELF 加载和程序运行区域 |

UART 的发送和接收状态都通过寄存器体现。最简单的应用方式：输出字符时，程序轮询发送状态并写入数据寄存器；输入字符时，交互程序可以轮询接收状态。模拟器的终端桥接会把宿主按键送入 UART，并把 UART 输出写回终端。

如果你需要在裸机程序中使用定时器中断或操作系统类功能，请参考 Chapter 0x03 中的异常处理和特权级内容。


## 项目导览

1. `test_resources/src/boot.S`：裸机程序的入口、栈初始化和进入 `main` 的过程。
2. `test_resources/linker.ld`：程序在 RAM 中的布局，RAM 默认从 `0x8000_0000` 开始。
3. `test_resources/Makefile`：编译参数、目标文件和 linker script 怎样组合成 ELF。
4. `test_resources/lib/io.c`：客户程序如何通过 UART 完成输入输出。
5. `test_resources/lib/power.c`：客户程序如何结束模拟器运行。

## 调试程序

参阅 [Ch0.2](./Ch0.2.md) `Debugger` 章节，来了解如何调试模拟器中运行的程序。

```bash
# 请使用 --release 来提高运行 emulator 本身的运行速度
cargo run --release -- /path/to/program -g
```

## 综合任务：移植一个自选裸机程序

选择一个自己感兴趣、适合在裸机环境运行、在终端中呈现的程序，将它移植到 RISC-V Emulator 上。终端游戏、计算器、命令解释器和单步推进的算法演示都可以作为方向，强烈推荐大家，将大一计算思维课写过的程序移植到riscv裸机运行。
