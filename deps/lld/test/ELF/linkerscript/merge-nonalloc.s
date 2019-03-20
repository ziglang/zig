# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { .text : { *(.text) *(.nonalloc) } }" > %t.script
# RUN: ld.lld -shared -o %t.exe %t.script %t.o
# RUN: llvm-objdump -syms %t.exe | FileCheck %s

# CHECK: .text 00000000 nonalloc_start

_start:
  nop

.section .nonalloc,"",@progbits
nonalloc_start:
  .long 0xcafe
