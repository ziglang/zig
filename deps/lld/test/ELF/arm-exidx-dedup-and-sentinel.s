// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t.o
// RUN: ld.lld %t.o -shared -o %t.so --section-start .text=0x2000 --section-start .ARM.exidx=0x1000
// RUN: llvm-objdump -s -triple=armv7a-none-linux-gnueabi %t.so | FileCheck %s

 .syntax unified

 .section .text.foo, "ax", %progbits
 .globl foo
foo:
 .fnstart
 bx lr
 .cantunwind
 .fnend

 .section .text.bar, "ax", %progbits
 .globl bar
bar:
 .fnstart
 bx lr
 .cantunwind
 .fnend

// CHECK: Contents of section .ARM.exidx:
// 1000 + 1000 = 0x2000 = foo
// The entry for bar is the same as previous and is eliminated.
// The sentinel entry should be preserved.
// 1008 + 1000 = 0x2008 = bar + sizeof(bar)
// CHECK-NEXT: 1000 00100000 01000000 00100000 01000000
