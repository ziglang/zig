# REQUIRES: x86 && !llvm-64-bits

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { .text : { . = 0x6fffffffffffffff; *(.text*); } }" > %t.script
# RUN: not ld.lld --no-check-sections --script %t.script %t.o -o /dev/null 2>&1 | FileCheck %s

# CHECK: output file too large

.global _start
_start:
  nop
