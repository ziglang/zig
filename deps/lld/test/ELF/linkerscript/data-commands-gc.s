# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { .text : { *(.text*) QUAD(bar) } }" > %t.script
# RUN: ld.lld --gc-sections -o %t %t.o --script %t.script
# RUN: llvm-objdump -t %t | FileCheck %s

# CHECK: 0000000000000008         .rodata                 00000000 bar

.section .rodata.bar
.quad 0x1122334455667788
.global bar
bar:

.section .text
.global _start
_start:
  nop
