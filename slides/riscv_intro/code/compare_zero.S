
./compare_zero.o:     file format elf64-littleriscv


Disassembly of section .text:

0000000000000000 <is_zero>:
   0:	fe010113          	addi	sp,sp,-32
   4:	00113c23          	sd	ra,24(sp)
   8:	00813823          	sd	s0,16(sp)
   c:	02010413          	addi	s0,sp,32
  10:	00050793          	addi	a5,a0,0
  14:	fef42623          	sw	a5,-20(s0)
  18:	fec42783          	lw	a5,-20(s0)
  1c:	0007879b          	addiw	a5,a5,0
  20:	00079663          	bne	a5,zero,2c <.L2>
  24:	00100793          	addi	a5,zero,1
  28:	0080006f          	jal	zero,30 <.L3>

000000000000002c <.L2>:
  2c:	00000793          	addi	a5,zero,0

0000000000000030 <.L3>:
  30:	00078513          	addi	a0,a5,0
  34:	01813083          	ld	ra,24(sp)
  38:	01013403          	ld	s0,16(sp)
  3c:	02010113          	addi	sp,sp,32
  40:	00008067          	jalr	zero,0(ra)
