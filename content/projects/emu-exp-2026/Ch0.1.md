---
title: "Chapter 0x00.1 - RISC-V 介绍与实验环境"
type: page
weight: 1
draft: false
showTableOfContents: true
---

## RISC-V 介绍

> TL;DR
> 
> RISC由美国加州大学伯克利分校教授David Patterson发明。
> RISC-V（读作”risk-five“），表示第五代精简指令集，起源于2010年伯克利大学并行计算实验室(Par Lab) 的1位教授和2个研究生的一个项目（该项目也由David Patterson指导），希望选择一款指令集用于科研和教学，该项目在x86、ARM等指令集架构中徘徊，最终决定自己设计一个全新的指令集，RISC-V由此诞生。RISC-V的最初目标是实用、开源、可在学术上使用，并且在任何硬件或软件设计中部署时无需版税。
> 
> 2015年，为了更好的推动RISC-V在技术和商业上的发展，3位创始人做了如下安排：
> - 成立RISC-V基金会，维护指令集架构的完整性和非碎片化
> - 成立SiFive公司，推动RISC-V商业化
>
> 2019年，RISC-V基金会宣布将总部迁往瑞士，改名RISC-V国际基金会。作为全球性非营利组织，已在全球70多个国家拥有2000+成员。包括华为、中兴、阿里巴巴、、乐鑫等众多国内企业。
通过十多年的发展，RISC-V这一星星之火已有燎原之势。倪光南院士表示，未来RISC-V很可能发展成为世界主流CPU之一，从而在CPU领域形成Intel (x86)、ARM、RISC-V三分天下的格局。

> [!TIP]
> 点击此处让 [AI](https://kimi.moonshot.cn/_prefill_chat?prefill_prompt=什么是riscv,为什么要学riscv&send_immediately=false&force_search=true) 介绍 :smile:

## HERE

`HERE` (HEU Educational Rust-based Emulator) 是一款自主开发的开源教学用 RISC-V 模拟器，支持 RV64GC 指令集和 uart、virtio-blk 等众多外设，带有内置调试器(`rvdb`)和 gdb 支持。采用 Rust 语言开发，兼具性能和安全。

如果您需要开启探索仓库之旅，可以参阅 [zread](https://zread.ai/here-emulator/here)，其中包含AI生成的项目详细解析，以及与LLM进行交互式探索代码的功能。(AI **未必完全正确**，请保持独立思考，请勿盲从)

仓库：[HERE](https://github.com/here-emulator/here)

## 环境配置

### Rust toolchain

需要安装 nightly 版本的 [rust](https://rust-lang.org/tools/install/) 工具链

- 对于大多数发行版如 Ubuntu: 

    ```bash
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    source "$HOME/.cargo/env" && rustup default nightly
    ```

- 对于 Arch Linux，可以使用 pacman 包管理：

    ```bash
    sudo pacman -S rustup
    source "$HOME/.cargo/env" && rustup default nightly
    ```

### RISC-V 交叉编译器

除非你使用的电脑或虚拟机是 RISC-V 指令集（如果你不清楚，则一定不是），否则你需要安装 RISC-V 的交叉编译器来编译、链接 RISC-V 程序。

下面的 bash 脚本会将预编译的交叉工具链安装到 `/opt/riscv`

```bash
export TOOLCHAIN_URL="https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/2025.11.21/riscv64-elf-ubuntu-22.04-gcc.tar.xz"

sudo mkdir -p /opt/riscv
wget $TOOLCHAIN_URL -O /tmp/toolchain.tar.xz

sudo tar -xvf /tmp/toolchain.tar.xz --strip-components=1 -C /opt/riscv

rm /tmp/toolchain.tar.xz
```

这之后，为了方便使用，你需要将 `/opt/riscv` 加入环境变量：

```bash
export PATH=/opt/riscv/bin:$PATH
```

也可以将这行代码放入 `.bashrc`（对于 bash）或者其他启动脚本中

测试：

```bash
riscv64-unknown-elf-gcc --version
```

GNU 的常用工具链都有包含，如 `gdb` 和 `objdump`。

### `HERE`

项目地址：[HERE](https://zread.ai/here-emulator/here)

如果你对该项目的使用需要额外的帮助，请参考项目的 readme；如果你遇到了问题，请检索或发表 issue

拉取项目源码和 submodule：

```bash
git clone https://github.com/here-emulator/here.git

git submodule init
git submodule update
```

编译并运行自带的 C 语言 demo 程序：（你需要先安装 `makefile`）

```bash
cd ./test_resources
make
cargo run --release -- ./bin/main.elf
```

### 测试

编译 `riscv-tests` 测试套件，从项目根目录下（你需要先安装 `autoconf` 和 `makefile`）：

```bash
export PATH=/opt/riscv/bin:$PATH
cd riscv-tests
autoconf
./configure --prefix=/opt/riscv
make
```

运行命令 `cargo test`，会同时运行项目内置的单元测试和 `riscv-tests`

### issue

如果遇到无法解决的 bug，请检查软件在终端的输出，和运行目录下的 log 文件夹下的日志。我们在仓库目录中有附上 `create_issue.md` 的 skill，您可以将遇到的 bug 告知您的 agent，交由 agent 提交 issue。
