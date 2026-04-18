---
title: "动态链接机制"
date: 2026-04-16T22:30:00+08:00
description: "动态链接的PLT和GOT机制"
tags: ["post", "C语言", "动态链接"]
type: post
weight: 25
showTableOfContents: true
lastmod: 2025-11-02
---


## 全局偏移表 GOT (Global Offset Table)

`elf` 文件中的一个段 (.got), 权限为 `rw-`. 该段与动态链接器共享, 当动态库想要获得某个只有动态链接器才知道的地址，就会把它预留好位置放到 .got 表当中, 例如外部函数/变量的地址, 以及其他链接器产生的, 运行时需要的变量.

`.got` 还有一个子段 `.got.plt`, `.got` 中是外部全局变量, `.got.plt` 是外部函数, `.got.plt` 会进行 `plt` 的 lazy 操作(后续会讲).

- `.got.plt[0]`：address of `.dynamic` section 也就是本ELF动态段(.dynamic段)的装载地址
- `.got.plt[1]`：address of `link_map` object (编译时填充0) 也就是本ELF的link_map数据结构描述符地址，作用：link_map结构，结合.rel.plt段的偏移量，才能真正找到该elf的.rel.plt
- `.got.plt[2]`：address of `_dl_runtime_resolve` function (编译时填充为0) `也就是_dl_runtime_resolve` 函数的地址，来得到真正的函数地址，回写到对应的got表位置中。

### `.dynamic` 段

用于为动态链接器提供必要的元数据, 其结构可以在 `elf.h` 中找到:

```c
typedef struct {
  Elf64_Sxword d_tag;
  union {
      Elf64_Xword d_val;
      Elf64_Addr d_ptr;
  } d_un;
} Elf64_Dyn;
```

详见 dynamic-section 文章.

## 过程链接表 PLT (Procedure Linkage Table)

`elf` 文件中的一个段 (.plt), 权限为 `--x`. 由于外部符号可能很多, 为了避免 `dlopen` 时突发延迟, `glibc` 做了一套 lazy 机制, 在函数被实际 `call` 的时候, 再通过 `PLT0` 函数进行符号解析, 将解析后的地址填入 `.got` 对应的项中, 后续的 `call` 则会直接命中 `.got` 中的函数.

## 来看一段代码

```c
// a.c -> a.so
#include <stdint.h>

uint32_t data1 = 1;
uint32_t data2 = 2;

uint32_t get_data1(void) {
    return data1;
}

uint32_t get_data2(void) {
    return data2;
}
```

```c
// main.c -> main.o --(a.so)--> main.elf
#include <stdint.h>
#include <stdio.h>
#include <dlfcn.h>

uint32_t get_data1(void);
uint32_t get_data2(void);

int main() {
    dlopen("./liba.so", RTLD_LAZY);
    extern uint32_t data1, data2;
    printf("%d\n", get_data1() + data2);
    printf("%d\n", get_data2() + data1);
    return 0;
}
```

在 `a.c` 中定义两个 `extern` 变量, 并给出两个访问函数, 在 `main.c` 中访问. 我们关注 `get_data` 和 直接访问 `data` 两者的区别, 查看 main.elf 的反汇编:

```bash
$ gcc -fPIC -Wall -Wextra main.c -c -o main.o
$ gcc -fPIC -Wall -Wextra main.o -L. -la -Wl,-rpath=. -o main.elf
$ objdump -D -R main.elf > main.elf.dump

0000000000001169 <main>:
    1169:	55                   	push   %rbp
    116a:	48 89 e5             	mov    %rsp,%rbp
    116d:	48 8d 05 90 0e 00 00 	lea    0xe90(%rip),%rax        # 2004 <_IO_stdin_used+0x4>
    1174:	be 01 00 00 00       	mov    $0x1,%esi
    1179:	48 89 c7             	mov    %rax,%rdi
    117c:	e8 cf fe ff ff       	call   1050 <dlopen@plt>
    1181:	e8 aa fe ff ff       	call   1030 <get_data1@plt>
    1186:	48 8b 15 43 2e 00 00 	mov    0x2e43(%rip),%rdx        # 3fd0 <data2>
    118d:	8b 12                	mov    (%rdx),%edx
    118f:	01 c2                	add    %eax,%edx
    1191:	48 8d 05 76 0e 00 00 	lea    0xe76(%rip),%rax        # 200e <_IO_stdin_used+0xe>
    1198:	89 d6                	mov    %edx,%esi
    ...

Disassembly of section .got:

0000000000003fb0 <.got>:
	...

Disassembly of section .got.plt:

0000000000003fe8 <_GLOBAL_OFFSET_TABLE_>:
    3fe8:	b0 3d                	mov    $0x3d,%al
```

### 动态链接的外部变量

```bash
    1186:	48 8b 15 43 2e 00 00 	mov    0x2e43(%rip),%rdx        # 3fd0 <data2>
    118d:	8b 12                	mov    (%rdx),%edx
```

第一行从 `%rip (=0x118d) + 0x2e43 = 0x3fd0 <data2>` 地址 `load` 了一个值到 `%rdx` 中, 该地址是 `.got` 表中, 指向 `load` 的地址, 随后将 `%rdx` 指向的值 (`data1`) load 到 `%edx`.

查看 `liba.so` 的反汇编:

```bash
$ gcc -S -fPIC -Wall -Wextra a.c -o a.s
$ gcc -c -fPIC -Wall -Wextra a.s -o a.o
$ ld -shared a.o -o liba.so
$ objdump -D -R liba.so > liba.dump

$Disassembly of section .got:

0000000000003fd8 <.got>:
	...
			3fd8: R_X86_64_GLOB_DAT	data1
			3fe0: R_X86_64_GLOB_DAT	data2
    
    ...

0000000000004000 <data1>:
    4000:	01 00                	add    %eax,(%rax)
	...

0000000000004004 <data2>:
    4004:	02 00                	add    (%rax),%al
	...
```

`data1, data2` 实际的值都在 `liba.so` 的 `.data` 段, 并在 `.got` 段预留了两个条目(`.got` 段的 **外部变量(不包括函数)** 会在初始化时填入0). 这两个条目在与 `main.o` 链接时会被附加到 `main.elf` 的 `.got` 段中:

```bash
$ cat main.elf.dump

Disassembly of section .got:

0000000000003fb0 <.got>:
	...
			3fb0: R_X86_64_GLOB_DAT	__libc_start_main@GLIBC_2.34
			3fb8: R_X86_64_GLOB_DAT	_ITM_deregisterTMCloneTable
			3fc0: R_X86_64_GLOB_DAT	data1
			3fc8: R_X86_64_GLOB_DAT	__gmon_start__
			3fd0: R_X86_64_GLOB_DAT	data2
			3fd8: R_X86_64_GLOB_DAT	_ITM_registerTMCloneTable
			3fe0: R_X86_64_GLOB_DAT	__cxa_finalize@GLIBC_2.2.5
```

接下来思考: `3fc0: R_X86_64_GLOB_DAT data1` 的值原本为 `0`, 但是在访问 `data1` 时, 该地址应当被填入正确的值. 然而显然我们没有做这件事, 因此又可以开始研究动态链接器了(~~伟大无需多言~~). 在 `main.elf` 中还有一个特殊的段:

```bash
$ readelf -r main.elf

Relocation section '.rela.dyn' at offset 0x5d8 contains 10 entries:
  Offset          Info           Type           Sym. Value    Sym. Name + Addend
000000003da0  000000000008 R_X86_64_RELATIVE                    1160
000000003da8  000000000008 R_X86_64_RELATIVE                    1110
000000004028  000000000008 R_X86_64_RELATIVE                    4028
000000003fb0  000100000006 R_X86_64_GLOB_DAT 0000000000000000 __libc_start_main@GLIBC_2.34 + 0
000000003fb8  000200000006 R_X86_64_GLOB_DAT 0000000000000000 _ITM_deregisterTM[...] + 0
000000003fc0  000500000006 R_X86_64_GLOB_DAT 0000000000000000 data1 + 0
000000003fc8  000700000006 R_X86_64_GLOB_DAT 0000000000000000 __gmon_start__ + 0
000000003fd0  000800000006 R_X86_64_GLOB_DAT 0000000000000000 data2 + 0
000000003fd8  000a00000006 R_X86_64_GLOB_DAT 0000000000000000 _ITM_registerTMCl[...] + 0
000000003fe0  000b00000006 R_X86_64_GLOB_DAT 0000000000000000 __cxa_finalize@GLIBC_2.2.5 + 0
```

用于在 main.elf 启动时, 通知动态链接器, `000000003fc0` 地址处, 有一个名为 `data1` 的 `R_X86_64_GLOB_DAT` 类型符号, 在 `dlopen` 时, 若发现该符号, 则写入该地址.

### 动态链接的外部函数

`1181:	e8 aa fe ff ff       	call   1030 <get_data1@plt>` 通过访问了 plt 函数, `实现lazy` 加载机制.

`.plt` 是一个函数表, 记录了动态链接的外部函数. 前面提到, 外部变量的地址会在 `.so` 载入时被填入 `.got` 中对应的项, 但是外部函数的数量远多于变量, 因此如果全部在动态链接时修改, 则载入延迟可能会非常大. 因此, 通过 `plt` 函数当作跳板(`plt` 函数仅有几条指令, 且不包含栈操作, 因此开销可以忽略), 每个外部函数都会自动生成一个对应的 `plt` 函数, 如 `get_data1` 会实际调用 `get_data1@plt`.

```bash
$ cat main.elf.dump

Disassembly of section .plt:

0000000000001020 <get_data1@plt-0x10>:
    1020:	ff 35 ca 2f 00 00    	push   0x2fca(%rip)        # 3ff0 <_GLOBAL_OFFSET_TABLE_+0x8>
    1026:	ff 25 cc 2f 00 00    	jmp    *0x2fcc(%rip)        # 3ff8 <_GLOBAL_OFFSET_TABLE_+0x10>
    102c:	0f 1f 40 00          	nopl   0x0(%rax)

0000000000001030 <get_data1@plt>:
    1030:	ff 25 ca 2f 00 00    	jmp    *0x2fca(%rip)        # 4000 <get_data1>
    1036:	68 00 00 00 00       	push   $0x0
    103b:	e9 e0 ff ff ff       	jmp    1020 <_init+0x20>

0000000000001040 <printf@plt>:
    1040:	ff 25 c2 2f 00 00    	jmp    *0x2fc2(%rip)        # 4008 <printf@GLIBC_2.2.5>
    1046:	68 01 00 00 00       	push   $0x1
    104b:	e9 d0 ff ff ff       	jmp    1020 <_init+0x20>
    
    ...

Disassembly of section .got.plt:

0000000000003fe8 <_GLOBAL_OFFSET_TABLE_>:
    3fe8:	b0 3d                	mov    $0x3d,%al
	...
    3ffe:	00 00                	add    %al,(%rax)
    4000:	36 10 00             	ss adc %al,(%rax)
			4000: *unknown*	get_data1
```

`get_data1@plt-0x10` 也被称为 `plt0`. 伪代码如下:

```assembly
plt0:
1020    push    link_map
1026    jmp     _dl_runtime_resolve

get_data1@plt:
jmp     *(.got.plt[get_data])
push    get_data.reloc_index
jmp     plt0
```

`get_data1@plt` 首先跳转到 `.got.plt` 中 `get_data1` 字段指向的地址 `(jmp *(0x4000))`

1. 非第一次执行时, 实际跳转到 `get_data1` 执行, `jmp` 指令为 `get_data1@plt` 的第一条指令, 并通过 `jmp` 进行跳转, 因此没有产生除pc改变外的任何副作用, `get_data1` 中的 `ret` 指令会直接返回 `call get_data1@plt` 的下一条指令, 全程没有额外分支指令, 避免流水线中断, 只有一次仿存, 性能开销几乎可以忽略不计.
2. 第一次执行时, 该字段地址的值为 `get_data1@plt + 6`, 即 `jmp *0x2fca(%rip)` 下一条指令, `push $0x0`. `get_data1` 是该 elf 中第一个动态链接的外部函数符号, `reloc_index` 为0, 将 0x0 压入栈中, 调用 `jmp 1020 (plt0)`, 由于每个 `elf` 的每个 `@plt` 函数都需要调用 plt0 中的这段代码, 因此被提取为 `plt0`, 而每个 `elf` 的 `plt0` 都需要调用查找实际函数地址并写回 `.got.plt` 的功能 (`_dl_runtime_resolve` 函数), 因此被进一步提取. 简而言之, 首次调用时会将当前 `elf` 的 `.got.plt[1](link_map)` 节点的地址, 和当前请求函数的编号压入栈中, 然后调用 `*(.got.plt[2])即(_dl_runtime_resolve)` 去解析外部符号.

#### `_dl_runtime_resolve`

- 该章节建议配合源码食用

`_dl_runtime_resolve` 函数在 `ld.so` 库中, 本身也是外部函数, 因此 `_dl_runtime_resolve` 本身肯定不能走这套流程解析, 因此在 `ld.so` 加载时, 操作系统 (可能是?) 会将这个函数的实际地址写入 `.got.plt[2]`.

`_dl_runtime_resolve` 代码位于 `glibc: sysdeps/x86_64/dl-trampoline.h`, 是一段平台相关的汇编函数. 此时栈为:
```
| reloc_index |
| link_map    |
| return addr |
```

`_dl_runtime_resolve` 保存了一大堆上下文之后调用一个 c 函数: 

```
# 压栈
call _dl_fixup  # Call resolver.
# 恢复栈
jmp *%r11       # Jump to function address.
``` 

```c
// sysdeps/hppa/dl-fptr.h
struct fdesc
  {
    ElfW(Addr) ip;	/* code entry point */
    ElfW(Addr) gp;	/* global pointer */
  };

// sysdeps/hppa/dl-lookupcfg.h
#define DL_FIXUP_VALUE_TYPE struct fdesc

// elf/dl-runtime.c
DL_FIXUP_VALUE_TYPE
attribute_hidden __attribute ((noinline)) DL_ARCH_FIXUP_ATTRIBUTE
_dl_fixup (
	   struct link_map *l, ElfW(Word) reloc_arg)
{
    ...
}
```
先读取段信息:

```c
symtab = DT_SYMTAB   // 符号表 (.dynsym)
strtab = DT_STRTAB   // 字符串表 (.dynstr)
pltgot = DT_PLTGOT   // GOT 基址
reloc = DT_JMPREL + offset(reloc_arg) = .rela.plt[reloc_index]

const ElfW(Sym) *sym = &symtab[ELFW(R_SYM) (reloc->r_info)]; // 符号项
```

查找 `.rela.plt`, `.dynsym` 得到 `get_data1` 的符号项, 再从 `.dynstr`, 即可得到 `0x0` 对应的符号为 `get_data1`, 然后拿着 `get_data1` 字符串调用 `_dl_lookup_symbol_x` 查找符号所在的 `.so` 模块和具体地址.

```
Relocation section '.rela.plt' at offset 0x6c8 contains 4 entries:
  Offset          Info           Type           Sym. Value    Sym. Name + Addend
000000004000  000300000007 R_X86_64_JUMP_SLO 0000000000000000 get_data1 + 0
000000004008  000400000007 R_X86_64_JUMP_SLO 0000000000000000 printf@GLIBC_2.2.5 + 0
000000004010  000600000007 R_X86_64_JUMP_SLO 0000000000000000 dlopen@GLIBC_2.34 + 0
000000004018  000900000007 R_X86_64_JUMP_SLO 0000000000000000 get_data2 + 0
```

顺序为 current_elf, DT_NEEDED, 递归查找依赖(依赖树, 如果子库中的 `.got.plt` 表已经有了该符号的地址, 则无须继续递归):

```c
void *const rel_addr = (void *)(l->l_addr + reloc->r_offset); // get_data1 在 .got.plt 表中地址(上述的0x4000)

lookup_t result;
result = _dl_lookup_symbol_x (strtab + sym->st_name, l, &sym, l->l_scope,
				    version, ELF_RTYPE_CLASS_PLT, flags, NULL); // 查找符号

SYMBOL_ADDRESS(result, sym); // 计算实际地址
elf_machine_fixup_plt (l, result, refsym, sym, reloc, rel_addr, value); // 回写 .got.plt 并返回 result
```

随后程序从 `_dl_fixup` 返回 `_dl_runtime_resolve`, 恢复现场之后调用 `_dl_runtime_resolve` 返回值指向的 `real function`. 完成 lazy 解析与执行机制.

其中又涉及到一个比较关键的数据结构: `link_map`.

#### link_map

> TODO: 本章节待补充

- `link_map` 是动态链接器的核心数据结构, 几乎所有与动态链接器的操作都需要 `link_map`. 每个动态链接的单元都有一个对应的 `link_map`, 里边包含了当前 `.so` 的所有重定向相关信息, 如 `Dynamic section` 的起始地址, 当前库的完整文件名等一大堆信息(`musl` 的实现会比 `glibc` 精简非常多).

## 其他问题

### musl libc

`glibc` 实现了 `plt` 的 lazy binding 机制, 但是 `musl libc` 选择抛弃该机制, 这样可以避免 `_dl_runtime_resolve` 这一非常复杂的实现方式, 以及在 link_map 中添加巨量符号相关信息. 在 `musl libc` 中, 外部函数与外部变量一样, 在动态链接时, 直接修改 `.got` 中的实际值, 即调用 `@plt` 函数的时候, 不会发生跳转 `plt0` 的情况. 同时 musl libc 这一设计也避免了接下来 `.got` 失效的问题

### 卸载后 `.got` 失效

- 如果一个库在运行时通过 `dlclose` 被卸载了, 然后之后又重新 `dlopen`, 此时该 `elf` 所在的地址很可能与之前不一样. (我们假设 `a.so` 调用了 `b.so` 的函数). `a.so` 的 `.got.plt` 表中之前已经被填入了之前 `b.so` 中符号的地址, 因此, 再次调用 `plt stub` 函数时, 不会进入 `plt0` 中. 但是 `.got.plt` 表中的地址是错误的, 需要重新解析符号, 否则其中 `.got.plt` 指向的地址是个无效地址, 会导致 plt 机制发生错误. 因此 glibc 提供了 `dlsym` 方法, 用于重新解析符号, `musl libc` 在 reopen 时必定会触发重新写入 `.got` 的行为. 同时为了避免 `.got` 失效后带来的开销, `glibc` 和 `musl libc` 的默认行为都是禁止一个动态链接的库被close.

## END

自此, 整个动态链接过程, 除了 `_dl_lookup_symbol_x()` 函数细节, 其余部分已经大致了解了一遍, 啥时候有空了再来补充吧 :heart: