// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// Use Linker script without .ARM.exidx Output Section so it is treated as
// an orphan. We must still add the sentinel table entry
// RUN: echo "SECTIONS { \
// RUN:          .text 0x11000 : { *(.text*) } \
// RUN:          } " > %t.script
// RUN: ld.lld --no-merge-exidx-entries --script %t.script %t -o %t2
// RUN: llvm-objdump -s -triple=armv7a-none-linux-gnueabi %t2 | FileCheck %s

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
// CHECK-NEXT: 0000 00100100 01000000 fc0f0100 01000000
