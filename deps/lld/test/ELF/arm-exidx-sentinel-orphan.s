// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// Use Linker script without .ARM.exidx Output Section so it is treated as
// an orphan. We must still add the sentinel table entry
// RUN: echo "SECTIONS { \
// RUN:          .text 0x11000 : { *(.text*) } \
// RUN:          } " > %t.script
// RUN: ld.lld --script %t.script %t -o %t2
// RUN: llvm-objdump -s -triple=armv7a-none-linux-gnueabi %t2 | FileCheck %s
// REQUIRES: arm

 .syntax unified
 .text
 .global _start
_start:
 .fnstart
 .cantunwind
 bx lr
 .fnend

// CHECK: Contents of section .ARM.exidx:
// 11004 - 4 = 0x11000 = _start
// 1100c - 8 = 0x11004 = _start + sizeof(_start)
// CHECK-NEXT: 11004 fcffff7f 01000000 f8ffff7f 01000000
