---
title: "线程本地变量"
date: 2026-04-16T22:30:00+08:00
description: "TLS变量与GOT表"
tags: ["post", "C语言"]
type: post
weight: 25
showTableOfContents: true
lastmod: 2025-11-02
---

## 线程本地变量

在多线程应用开发中, 对于不希望在现场间共享, 但是又希望全局可见的变量, 我们提供了一种 `tls` 变量的实现机制, 允许定义线程本地的全局变量. 在c/cpp中, 可以使用 `__thread int data` 来定义一个线程本地变量, 该变量在编译后会记录在 `.tbss, .tdata` 两个段中, 与 `.bss, .data` 段对应. 由于 `.rodata` 段不可写入, 因此线程本地的 read-only 对象没有意义.

为了让每个变量只能访问自己线程的 `tls` 变量, 需要将其保存在进程上下文中, 在 `x86_64` 架构中, 与线程相关的变量均被保存与 `%fs` 寄存器指向的 (Thread Control Block中):

```c
struct pthread {
	/* Part 1 -- these fields may be external or
	 * internal (accessed via asm) ABI. Do not change. */
	struct pthread *self;
#ifndef TLS_ABOVE_TP
	uintptr_t *dtv;
#endif
	struct pthread *prev, *next; /* non-ABI */
	uintptr_t sysinfo;
    
    ...

	/* Part 2 -- implementation details, non-ABI. */
	int tid;
	int errno_val;
	
    ...

	/* Part 3 -- the positions of these fields relative to
	 * the end of the structure is external and internal ABI. */
#ifdef TLS_ABOVE_TP
	uintptr_t canary;
	uintptr_t *dtv;
#endif
};
```

其中 `uintptr_t *dtv;` 用于维护 `tls` 变量信息, 由于每个动态链接单元都可能有自己的 `tls` 变量, 他们散步在虚拟内存空间的不同地方, 因此需要一个机制来访问这些变量.

![dtv图](/posts_data/thread_local_storage/dtv.png)

对当前 `elf` 内部定义的 `tls` 变量, 默认会通过相对偏移地址访问(PIC). 对其他 `shared object` 的访问会则会复杂很多, 下面展开分析.

---

## 动态库中的 `tls` 变量

按链接库的加载时机分为两种情况:
1. 被标记为 DL_NEEDED 的库, 在 main 函数所在的 `elf` 载入内存前, 就会被连同载入内存.
2. 使用 dlopen 手动加载的库, 这部分 `shared object` 的 tls 段内存在 dlopen 时才会动态在内存中分配.

### init exec TLS modle

在 main 函数执行前被载入内存, 那么为了方便仿存, 动态链接器会将这些 `shared object` 的 tls 内存段和 tcb(*%fs) 放在连续的内存上, 之后访问 tls 变量就可以直接通过 %fs 偏移.

从例子开始看起:

```c
__thread int tls_data1;
__thread int tls_data2;

int read_tls_data1() {
    return tls_data1;
}

int read_tls_data2() {
    return tls_data2;
}
```

通过 `-ftls-model=initial-exec` 限制该库只能在 initial 时被加载, 从而获得优化. 观察编译产生的汇编:

```bash
$ gcc -ftls-model=initial-exec -fPIC -O2 -S tls.c
$ cat tls.s
read_tls_data1:
        movq    tls_data1@gottpoff(%rip), %rax
        movl    %fs:(%rax), %eax
        ret

read_tls_data2:
        movq    tls_data2@gottpoff(%rip), %rax
        movl    %fs:(%rax), %eax
        ret
```

它首先从 `symbol@gottpoff(%rip)` 读取一个 offset 到 `%rax` 寄存器, 再从 `%fs:(%rax)` 地址读取 TLS 变量的值. 上面提到, 在 initial exec TLS model 下, TLS 空间是可以相对 `%fs` 寻址的, 但是 offset 无法提前得知, 需要由动态链接器完成重定位. 

```bash
$ as tls.s -o tls.o
$
 objdump -S -r tls.o
# omitted
0000000000000000 <read_tls_data1>:
   0:   48 8b 05 00 00 00 00    mov    0x0(%rip),%rax        # 7 <read_tls_data1+0x7>
                        3: R_X86_64_GOTTPOFF    tls_data1-0x4
   7:   64 8b 00                mov    %fs:(%rax),%eax
   a:   c3                      ret
   b:   0f 1f 44 00 00          nopl   0x0(%rax,%rax,1)

0000000000000010 <read_tls_data2>:
  10:   48 8b 05 00 00 00 00    mov    0x0(%rip),%rax        # 17 <read_tls_data2+0x7>
                        13: R_X86_64_GOTTPOFF   tls_data2-0x4
  17:   64 8b 00                mov    %fs:(%rax),%eax
  1a:   c3                      ret
```

在 mov 指令的立即数部分, 创建了一个 `R_X86_64_GOTTPOFF` 类型的重定位符, 告诉动态链接器, 在 .got 表中填写对应 symbol 相对 `%fs` 的偏移, 并将 `.got` entry 的相对 `mov` 指令的地址填入 `mov` 的立即数内.

进一步链接成 .so:

```bash
$ gcc -shared tls.o -o libtls.so
$
 objdump -D -S -R libtls.so
# omitted
Disassembly
 of section .text:

0000000000001100 <read_tls_data1>:
    1100:       48 8b 05 d1 2e 00 00    mov    0x2ed1(%rip),%rax        # 3fd8 <tls_data1+0x3fd4>
    1107:       64 8b 00                mov    %fs:(%rax),%eax
    110a:       c3                      ret
    110b:       0f 1f 44 00 00          nopl   0x0(%rax,%rax,1)

0000000000001110 <read_tls_data2>:
    1110:       48 8b 05 a9 2e 00 00    mov    0x2ea9(%rip),%rax        # 3fc0 <tls_data2+0x3fc0>
    1117:       64 8b 00                mov    %fs:(%rax),%eax
    111a:       c3                      ret

Disassembly
 of section .got:

0000000000003fb8
 <.got>:
        ...
                        3fc0: R_X86_64_TPOFF64  tls_data2
                        3fd8: R_X86_64_TPOFF64  tls_data1
```

可以看到:

1. 两个 tls 变量被写入了 `.got` 表中;
2. `.got` 的地址被写入了 mov 指令的立即数 (静态链接器完成了符号重定位);
3. 运行时, 为了读取 tls 变量的值, 先从 `.got` 表中取出 tls_data 相对 `%fs` 的偏移, 然后通过 `%fs+ offset` 访问.

### local/global dynamic TLS model

第二种情况是, 该库可能被 `dlopen` 加载, 因此 tls 段的 base 相对于 `%fs` 在编译期并不固定.

此时又分为两种情况:
1. 要访问的 tls 变量在 `shared object` 内部, 此时由于 tls base 地址在编译期不确定(由于多个线程会有多个 tls 内存区域, 因此不能通过相对偏移访问 tls). 因此需要通过 `__tls_get_addr` 函数间接找到 tls_data 的地址. 这种情景叫做 local dynamic TLS model(`-ftls-model=local-dynamic`).
2. 要访问的 tls 变量在当前 `shared object` 外部定义, 此时由于不知道 `tls data` 在哪个 `.so` 中, 也不知道它在 so 中的偏移. 这种情景叫做 global dynamic TLS model (`-ftls-model=global-dynamic(default)`), 为最通用的情况.

#### local dynamic TLS model

核心函数为 `__tls_get_addr`, 在 `musl` 的实现如下:

```c
#define tls_mod_off_t unsigned long long

// tls_mod_off_t[0] -> uint64_t ti_module
// tls_mod_off_t[1] -> uint64_t ti_offset
// #define pthread* pthread_t

void *__tls_get_addr(tls_mod_off_t *v)
{
	pthread_t self = __pthread_self();
	return (void *)(self->dtv[v[0]] + v[1]);
}
```

该函数需要两个参数, 第一个参数标识 tls 变量在哪个 `shared object` 中, 第二个参数标识 tls 变量相对 tls base 的偏移. 根据前面的 dtv 图, `pcb->dtv[module_index] + tls_offset` 即为目标 tls 变量地址.

```bash
$ gcc -ftls-model=local-dynamic -fPIC -O2 -S tls.c
$ cat tls.s
read_tls_data1:
.LFB0:
        subq    $8, %rsp
        leaq    tls_data1@tlsld(%rip), %rdi
        call    __tls_get_addr@PLT
        movl    tls_data1@dtpoff(%rax), %eax
        addq    $8, %rsp
        ret

read_tls_data2:
        subq    $8, %rsp
        leaq    tls_data2@tlsld(%rip), %rdi
        call    __tls_get_addr@PLT
        movl    tls_data2@dtpoff(%rax), %eax
        addq    $8, %rsp
        ret
```

生成了两个链接器变量:
1. `tls_data1@tlsld` 指示链接器生成 `R_X86_64_TLSLD` 类型的 `relocation`, 它的意思是在 .got 表中生成一个 entry, 这个 entry 会保存当前动态库对应的编号(由动态链接器在 dlopen 时填入), 然后该编号存入 `%rdi`, 然后作为参数传给 `__tls_get_addr` 获取当前 `shared object` 的 tls base address.
2. `tls_data1@dtpoff` 指示链接器生成 `R_X86_64_DTPOFF32` 类型的 `relocation`, 在链接时将 `tls_data1` 在 `plt` 中的 offset 填入此处, 再与加上 base, 得到 tls data 的实际地址.

查看生成的 .so 文件

```bash
$ gcc -shared tls.o -o libtls.so
$
 objdump -D -R libtls.so
# omitted
Disassembly
 of section .text:

0000000000001110 <read_tls_data1>:
    1110:       48 83 ec 08             sub    $0x8,%rsp
    1114:       48 8d 3d 9d 2e 00 00    lea    0x2e9d(%rip),%rdi        # 3fb8 <_DYNAMIC+0x1c0>
    111b:       e8 10 ff ff ff          call   1030 <__tls_get_addr@plt>
    1120:       8b 80 04 00 00 00       mov    0x4(%rax),%eax
    1126:       48 83 c4 08             add    $0x8,%rsp
    112a:       c3                      ret
    112b:       0f 1f 44 00 00          nopl   0x0(%rax,%rax,1)

0000000000001130 <read_tls_data2>:
    1130:       48 83 ec 08             sub    $0x8,%rsp
    1134:       48 8d 3d 7d 2e 00 00    lea    0x2e7d(%rip),%rdi        # 3fb8 <_DYNAMIC+0x1c0>
    113b:       e8 f0 fe ff ff          call   1030 <__tls_get_addr@plt>
    1140:       8b 80 00 00 00 00       mov    0x0(%rax),%eax
    1146:       48 83 c4 08             add    $0x8,%rsp
    114a:       c3                      ret

Disassembly
 of section .got:

0000000000003fb8
 <.got>:
        ...
                        3fb8: R_X86_64_DTPMOD64 *ABS*
```

两个函数调用 `__tls_get_addr` 时, 使用的参数都是 `0x3fb8`, 改地址即为 .got 表中保存当前 `shared object` 编号的地址(后面空了 8 字节的全 0 空间, 表示 `ti_offset` 为 0).


特别地, 如果在一个函数里访问多个当前动态库的 TLS 变量, 那么 __tls_get_addr 调用是可以合并的：

```c
__thread int tls_data1;
__thread int tls_data2;

int read_tls_data() { return tls_data1 + tls_data2; }
```

会生成如下的汇编:

```bash
$ gcc -ftls-model=local-dynamic -fPIC -O2 -S tls.c
$ cat tls.s
read_tls_data:
.LFB0:
        subq    $8, %rsp
        leaq    tls_data1@tlsld(%rip), %rdi
        call    __tls_get_addr@PLT
        movl    tls_data1@dtpoff(%rax), %edx
        addl    tls_data2@dtpoff(%rax), %edx
        addq    $8, %rsp
        movl    %edx, %eax
        ret
```

这样就减少了一次 __tls_get_addr 的调用.

#### global dynamic TLS model

最后一种情况, 访问的是外部动态链接库的全局tls变量, 此时只有变量的符号信息, 需要动态链接器去查找其属于哪个库, 偏移是多少.

```bash
$ gcc -ftls-model=global-dynamic -fPIC -O2 -S tls.c
$ cat tls.s
read_tls_data1:
        subq    $8, %rsp
        data16  leaq    tls_data1@tlsgd(%rip), %rdi
        .value  0x6666
        rex64
        call    __tls_get_addr@PLT
        movl    (%rax), %eax
        addq    $8, %rsp
        ret

read_tls_data2:
        subq    $8, %rsp
        data16  leaq    tls_data2@tlsgd(%rip), %rdi
        .value  0x6666
        rex64
        call    __tls_get_addr@PLT
        movl    (%rax), %eax
        addq    $8, %rsp
        ret
```

这次出现了一些不一样的内容: `data16、.value 0x6666 和 rex64`; 实际上, 这些是无用的指令前缀, 不影响指令的语义, 但是保证了这段代码有足够的长度, 方便后续链接器进行优化. 除了这些奇怪的前缀, 核心就是 `symbol@tlsgd(%rip)` 语法, 它会创建 `R_X86_64_TLSGD` relocation, 表示让链接器在 .got 中创建一对 entry, 一个表示 `ti_module`, 另一个表示 `ti_offset`, 构成一个 `tls_index` 结构体. 与 `local dynamic` 相比, 多了一个 `ti_offset` 无法在链接时得知, 需要动态链接器给出. 将 .got 中的 `tls_index` 结构体作为参数传给 `__tls_get_addr` 函数, 获得 `tls_data` 实际的地址.

在 `shared object` 加载时, 动态链接器会将 .got 表中的 `ti_module` 和 `ti_offset` 和其他 .got 表中的变量一起填入.