# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "SECTIONS { \
# RUN:      .init_array : { \
# RUN:        __init_array_start = .; \
# RUN:        *(.init_array) \
# RUN:        __init_array_end = .; } }" > %t.script
# RUN: ld.lld %t.o -script %t.script -o %t 2>&1

.globl _start
.text
_start:
  nop

.section .init_array, "aw"
  .quad 0
