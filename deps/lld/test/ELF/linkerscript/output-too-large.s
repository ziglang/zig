# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=i686-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { .text : { . = 0xffffffff; *(.text*); } }" > %t.script
# RUN: not ld.lld --no-check-sections --script %t.script %t.o -o /dev/null 2>&1 | FileCheck %s
# CHECK: error: output file too large

.global _start
_start:
  nop
