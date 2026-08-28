---
title: "Appendix A. 常用资料"
type: page
weight: 100
draft: false
---

## RISC-V 指令集资料

- [RISC-V ISA 手册](https://github.com/riscv/riscv-isa-manual): RISC-V 指令集官方的手册。
- [The RISC-V Reader](https://ysyx.oscc.cc/books/riscv-reader.html): 一本深入浅出介绍 RISC-V 的入门书籍，短小精悍，由 RISC-V 创始人之一的 David Patterson 和 Andrew Waterman 所著。本书有由中科院计算所团队翻译的免费的中文电子版。
- [RISC-V V 扩展手册](https://github.com/riscv/riscv-v-spec): RISC-V 向量扩展（Vector Extension）官方规范仓库。
- [RISC-V P 扩展手册](https://github.com/riscv/riscv-p-spec): RISC-V Packed-SIMD 扩展官方规范仓库（针对 8-bit/16-bit 打包计算）。
- [RISC-V AME 矩阵扩展手册](https://github.com/riscv/riscv-matrix-extension): RISC-V 高级矩阵扩展（Advanced Matrix Extension）官方规范仓库（针对 GEMM/AI 张量矩阵计算）。

## RISC-V 中断设备资料

- [PLIC 手册](https://github.com/riscv/riscv-plic-spec) `PLIC` 是 `RISC-V` 架构首选的平台级中断控制器(外设中断控制器)，由 `RISC-V` 官方社区维护。
- [ACLINT 手册](https://github.com/riscvarchive/riscv-aclint) `ACLINT` 是 `RISC-V` 架构常用的时钟和软件中断控制器，目前已经归档。

## 外设文档

- [virtio-v1.3](https://docs.oasis-open.org/virtio/virtio/v1.3/virtio-v1.3.html) `virtio` 是一类半虚拟化总线设备协议，支持 `PCIe`，`MMIO`，`Channel I/O` 三类总线，提供 `Block`, `NET`, `Console` 等常见的虚拟化设备议。
- [Uart 16550](https://pdos.csail.mit.edu/6.S081/2024/lec/16550.pdf) 一类常用的串口协议。
- [W25Q512JV](https://datasheet4u.com/pdf/1411833/W25Q512JV.pdf) 512bits (64mbytes) `SPI-FLASH` 设备。
- [sifive-u540](https://www.sifive.com/document-file/freedom-u540-c000-manual) 芯片数据手册，其中包含 Sifive-SPI，CLINT，和中断相关的介绍。

## :crab: Rust 库文档

- [Tokio 官方文档](https://tokio.rs/): `Tokio` 是 Rust 的一个无栈协程运行时实现。
- [Clap](https://docs.rs/clap/latest/clap/): `Clap` 是一个命令行解析工具, 支持使用派生宏来非常便捷且直观地实现命令行参数解析.