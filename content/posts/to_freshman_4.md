---
title: "`linux` 操作系统和 shell 的基础"
description: "linux and shell"
tags: ["tutor", "2025_简单聊聊", "post", "linux"]
type: 'post'
weight: 20
showTableOfContents: true
date: 2025-11-01T14:00:00+08:00
lastmod: 2025-11-02
---

## `linux`

世界上搭载机器最多的操作系统(不是使用人数), 广泛用于嵌入式, 服务器, 超算, 游戏主机, 移动终端(android), 个人pc.


`linux` 全称: `GNU Linux`, 诞生于 Spe 17, 1991. 赫尔辛基大学的学生 linus 在学完操作系统课之后, 打算参照当时教学用的系统 `minix` 写一个更完整的操作系统用于替代付费的 `Unix` 供自己使用. 第一个正式版(1.0.0)发布与1994年, 通过FTP服务分发, 最初的名字为 Unix Like Operation System. GNU社区管理员为了方便管理, 将其命名为 Linus's Unix(简称Linux).

`linux` 自诞生以来就有一个明显的特点: 由程序员开发, 为程序员服务(用户是程序员/计算机工程师). `linux` 诞生之后, 迅速吸引了一大批计算机爱好者(天下苦 `Unix` 久已), 大家纷纷为 `linux` 做驱动适配, 功能开发, 社区维护. 后来为了方便维护 `linux`, `git` 诞生(前文提到过).

经过十余年的发展, 2005年之后, 各大公司也加入了 `linux` 社区, 目前 `linux` 的最大开发者为: intel, AMD, arm, 高通, 瑞芯微, 华为等.

`linux` 本身是一个内核: 需要配套各种软件使用, 完整可用的系统一般被叫做发行版, 例如: Red Heat, `Ubuntu`, CentOS, `ArchLinux` 等. 他们的区别是搭载了不同的软件. 需要注意, 此处说的软件和 `windows` 下的软件有所不同, 在 `linux` 下, 桌面, 终端, 登录器 , 系统服务管理器, 都是在内核之外的软件.

### `linux` 的组成部分 (简单过一遍)

操作系统的本质: 管理硬件的各种资源, 具体方式是 **抽象**.

现代 `linux` 大体可以分为 5 个部分: 调度子系统, 内存子系统, 文件系统, 进程间通讯子系统, 网络子系统.

![kernel map](/posts_data/linux_and_shell/kernel_map.png)

1. 调度, cpu只有一个, 但是操作系统允许同时(宏观意义)运行多个程序. 操作系统将每个运行的程序 **抽象** 为一个个task, cpu负责为这些task分配各类硬件资源. 其中管理cpu资源分配的就是调度系统.
2. 内存, 
   1. 防止内存竞争: 计算机的物理内存编码唯一, 但是多个软件会运行在同一个计算机上, 为了防止多个应用程序争夺内存, 操作系统和硬件将物理内存 **抽象** 为虚拟内存, 应用程序开发过程可以假设整个内存空间只有自己一个程序在运行. 
   2. 方便管理内存资源, 和内存安全(r/w/x/privilage), 现在采用页表(过去还有段式/段页式), 将内存分为4k(2m/1g)大小的页.
3. 文件系统: 将磁盘抽象为文件目录层次, 同时管理磁盘缓存等, 高级的文件系统还有 cow, 快照, RAID, 透明压缩, 冷热文件管理等功能.
4. ipc: 将进程间的通讯渠道 **抽象** 为通道, 实际底层使用 网络回环, 共享内存或是其他, 应用可以不关心(也可以关心). 操作系统保护通讯的安全性.
5. 网络子系统: 将网卡设备 **抽象** 为一个文件, 应用只需要写入数据, 网络子系统会将其打包, 确认信道, 发送以及确认.

### `shell`

`shell` 是 `linux` 与用户交互的直接接口, 几乎一切需求都可以在 `shell` 上完成. `shell` 也有自己的固定语法, 一般来说遵循: 

```bash
command(execueable file) --option [others]
```

其中大部分 `command` 都是可执行文件(刚开始不用区分).

常用的 `shell` 命令:

```bash
ls
cd [path/-]         # - 为上次访问的目录
mkdir

cat
head ./a.c -n 10
tail ./b.c -n 10    # 常用于查看log
echo
touch           # 刷新文件修改日期(常用于创建文件)
vim             # 命令行编辑器, 还有nvim, nano, vi等

find            # 查找文件
grep            # 匹配
xargs           # 将管道输入转换为命令行参数
find -name "*.c" -or -name "*.txt" | xargs grep "#*<*>" | wc -l

man         # manual 手册

lscpu       # 查看cpu信息
lsblk       # 查看磁盘分区与挂载
lsmod       # 查看驱动 配合grep确认驱动是否存在
lsmem       # 查看内存与虚拟内存
uname -a    # 查看内核信息
top         # 资源管理器, 上位替代有 btop, htop

poweroff    # 关机(同时断电)
halt        # 关闭 linux, 但是不断电

# 包管理
apt install xxx     # debian 系
yum install xxx     # yum 系
pacman -S xxx       # arch
paru -S xxx         # Aur
dpkg install xxx

```

### linux 设计哲学

#### 一切皆文件

驱动, 进程, 设备等, 在linux下都被抽象为统一的文件(实现了 `file_operations` 接口). 对文件的操作本质也是对磁盘设备的操作, 因此, linux将两者统一管理. 例如, 树莓派上有一颗led, 我想点亮他只需要向 `/dev/gpio_led` write 一个 `1` 即可. 更复杂的设备也是同理, 用户只需要向各种接口写入值, 即可与驱动交互.

通过 `ls -l` 可以查看文件的详细属性, 其中每行的第一个字符为文件类型, linux共有7种文件类型:
1. `-`: 普通文件
2. `d`: 目录
3. `l`: 链接文件
4. `b`: 块设备
5. `c`: 字符设备
6. `s`: 套接字文件
7. `p`: 管道文件

#### do one thing well

`linux` 本身只是内核, 内核以外的系统组件不归 `linux` 管, 如包管理平台, 桌面, 系统软件等.

#### 模块化

`linux` 最高层级分为 5 个自摸块, 向下会继续细分. 部分模块可以在编译时自由裁剪和组合, 驱动模块可以在运行时热挂载. ~~`linux` 的驱动设计非常有趣~~

#### trust user

相信用户一定是对的, 无论什么操作, 只要权限足够(linux权限比windows简单, 但是并不意味着安全性低), 都会被系统执行. 例如(**请勿尝试!!!**): 

```bash
sudo rm -rf /*
```