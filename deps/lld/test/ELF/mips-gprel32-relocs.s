# Check R_MIPS_GPREL32 relocation calculation.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: ld.lld -shared -o %t.so %t.o
# RUN: llvm-objdump -s -section=.rodata -t %t.so | FileCheck %s

# REQUIRES: mips

  .text
  .globl  __start
__start:
  lw      $t0,%call16(__start)($gp)
foo:
  nop
bar:
  nop

  .section .rodata, "a"
v1:
  .gpword foo
  .gpword bar

# CHECK: Contents of section .rodata:
# CHECK:  00f4 fffe8014 fffe8018
#              ^ 0x10004 - 0x27ff0
#                       ^ 0x10008 - 0x27ff0

# CHECK: SYMBOL TABLE:
# CHECK: 00010008         .text           00000000 bar
# CHECK: 00010004         .text           00000000 foo
# CHECK: 00027ff0         *ABS*           00000000 .hidden _gp
