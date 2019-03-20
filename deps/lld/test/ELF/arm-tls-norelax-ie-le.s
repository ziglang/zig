// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %p/Inputs/arm-tls-get-addr.s -o %t1
// RUN: ld.lld %t1 --shared -o %t1.so
// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=armv7a-linux-gnueabi
// RUN: ld.lld --hash-style=sysv %t1.so %t.o -o %t
// RUN: llvm-objdump -s -triple=armv7a-linux-gnueabi %t | FileCheck %s

// This tls Initial Exec sequence is with respect to a non-preemptible symbol
// so a relaxation would normally be possible. This would result in an assertion
// failure on ARM as the relaxation functions can't be implemented on ARM.
// Check that the sequence is handled as initial exec
 .text
 .syntax unified
 .globl  func
 .p2align        2
 .type   func,%function
func:
.L0:
 .globl __tls_get_addr
 bl __tls_get_addr
.L1:
 bx lr
 .p2align 2
 .Lt0: .word  x1(gottpoff) + (. - .L0 - 8)
 .Lt1: .word  x2(gottpoff) + (. - .L1 - 8)

 .globl  x1
 .section       .trw,"awT",%progbits
 .p2align  2
x1:
 .word 0x1
 .globl x2
 .section       .tbss,"awT",%nobits
 .type  x1, %object
x2:
 .space 4
 .type x2, %object

// CHECK: Contents of section .got:
// x1 at offset 0x20 from TP, x2 at offset 0x24 from TP. Offsets include TCB size of 0x20
// CHECK-NEXT: 13064 20000000 24000000
