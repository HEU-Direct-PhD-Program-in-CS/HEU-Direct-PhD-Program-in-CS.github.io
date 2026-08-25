---
title: "Chapter 0x04 - 中断、异常与特权级"
type: page
weight: 40
draft: false
showTableOfContents: true
mermaid: true
---

## 本章概览

本章关注正常指令流被打断后发生了什么。异常、中断、系统调用和特权级切换最终都会进入 trap 流程，但它们从哪里来、保存什么信息、处理后回到哪里并不完全相同。

实验会同时观察客户程序和模拟器：客户程序负责设置入口、保存通用寄存器和编写 handler；模拟器负责判断 trap 是否发生、更新相关 CSR、切换特权级并改变 PC。把两侧的动作按时间顺序对起来，是理解本章最直接的方法。

## 特权级与 Trap 机制

### 特权级概述

为了保护硬件资源不被错误编写的或恶意的程序破坏，现代体系结构会设计不同数量的特权等级。RISC-V 定义了三种特权级（若不开启 H 扩展），从高到低：

- **M-mode（Machine）**：最高特权模式，拥有访问所有系统功能和物理资源的权限。
- **S-mode（Supervisor）**：中间特权模式，用于运行操作系统内核。
- **U-mode（User）**：最低特权模式，用于运行用户程序。

### 异常处理

特权等级一个重要的特性是拦截和处理异常（trap）。异常发生时，会从低特权等级变为高特权等级，运行高特权等级指定的异常处理程序，来决定如何处理异常。这允许操作系统或者嵌入式运行环境提供众多的功能，例如多任务、对硬件的抽象。

RISC-V 将 trap 分为两类：

| 类型              | 触发方式                 | 例子                                                      |
| ----------------- | ------------------------ | --------------------------------------------------------- |
| 异常（Exception） | 指令执行触发，**同步**   | 非法指令、断点、地址未对齐、缺页、ecall                   |
| 中断（Interrupt） | 外部或时钟事件，**异步** | 定时器中断（`MTI`）、外部中断（`MEI`）、软件中断（`MSI`） |

在执行 `ecall` 指令时，会引发环境调用异常，专门用来让低特权等级向高特权等级进行请求，例如操作系统的系统调用。

接下来以在 M mode 处理异常为例，讲解一个简化的异常处理流程，省略掉不重要的 CSR 字段。如果你想了解更详细的流程应该参考手册或模拟器的代码（src/isa/riscv/trap/trap_controller.rs）。

异常处理流程需要用到许多关键的 CSR（控制寄存器）：

- mip（Machine Interrupt Pending），记录当前的中断请求
- mie（Machine Interrupt Enable），处理器是否相应某种中断
- mcause（Machine Exception Cause），指示发生了何种异常
- mtvec（Machine Trap Vector），存放发生异常时处理器应该跳转的地址
- mtval（Machine Trap Value），存放当前异常相关的额外信息，如访存异常保存故障地址
- mepc（Machine Exception PC），发生异常的指令地址
- mscratch（Machine Scratch），给异常处理程序准备的临时寄存器

如果当前指令遇到异常，或者在运行指令之前检测到中断，则会进入异常处理流程：

1. 保存异常相关信息：
   - `mtval` <- 异常相关地址或非法指令编码
   - `mcause` <- trap 原因
2. 保存上下文，保存 trap 前的状态，用于从 trap 中返回：
   - `mstatus.MPP` <- 当前特权级
   - `mepc` <- 当前 PC
   - `mstatus.MPIE` <- `mstatus.MIE`，
   - 清除 `mstatus.MIE`（为了避免立刻再次相应中断）
3. 切换 PC：根据 `mtvec` 的 base 和 mode（Direct 或 Vectored）计算 handler 地址。在 direct 模式下就是直接跳转到 base 的地址。

这之后交由软件来处理异常。

### 从 Trap 返回

当软件处理完异常后，需要从异常返回原本的位置，这在 M mode 通过 `mret` 指令实现：

- `mstatus.MIE` <- `mstatus.MPIE`
- `mstatus.MPIE` <- 1
- 恢复 PC <- `mepc`
- 当前特权模式 <- `mstatus.MPP`

这基本上就是发生异常时保存上下文的逆操作。

## 项目导览

模拟器侧：

- `src/isa/riscv/trap/trap_controller.rs`：`TrapController`，核心的 trap 调度逻辑。
- `src/isa/riscv/trap/mod.rs`：`Interrupt` 和 `Exception` 枚举定义，以及各自的 `Into<WordType>` 实现（决定 mcause 值）。
- `src/isa/riscv/executor.rs`：中断检查和执行异常进入 trap 的位置。

用户程序侧：

- `test_resources/include/trap.h`：`TrapContext` 结构体定义和 CSR 地址宏。
- `test_resources/lib/trap.S`：`__traps_entry` / `__traps_return` 汇编，保存/恢复通用寄存器并调用 `trap_handler`。
- `test_resources/lib/trap_handler.c`：默认的 trap handler，以及 `trap_init()` 设置 `mtvec`、`mie`、`mstatus` 的流程。
- `test_resources/src/trap_test.c`、`ecall_test.c`、`clint.c`：已有的简单 demo 程序。
- `test_resources/src/clint.c` 演示了在 M-mode 下使用定时器中断的基本流程。

## 综合实验任务：M-mode monitor

实现一个小型 M-mode monitor，由它启动多个 U-mode 测试程序。

- monitor 能够从 M-mode 进入 U-mode 运行任务，并在 trap 后可靠返回 M-mode 的 trap handler
- 设计几个通过 `ecall` 进入的简单服务，例如字符输出、`sleep`、启动新任务和退出，让 U-mode 程序通过统一接口请求 monitor 服务
- 在 U-mode 程序中安排一项环境调用以外的异常，例如非法指令或非法访存，并检查 mcause、mepc 和 mtval 是否符合预期
- 为各类 trap 选择合适的恢复方式：返回原位置、跳过触发指令、或者结束 U-mode 程序
- 接收并处理 CLINT 定时器中断，在所有 U-mode 程序中公平地分配时间片, 即简单的多道批处理系统

### 扩展任务

实现更好的类似 RTOS 的抢占式调度：给 U-mode 程序设定优先级，总是运行当前活跃的最高优先级的程序，在多个同优先任务中公平分配时间（注意 `yield` 和 `sleep` 的实现, 尽可能减少 `CPU` 的忙等)
