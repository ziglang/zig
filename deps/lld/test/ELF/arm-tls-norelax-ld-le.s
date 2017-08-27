// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %p/Inputs/arm-tls-get-addr.s -o %t1
// RUN: ld.lld %t1 --shared -o %t1.so
// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=armv7a-linux-gnueabi
// RUN: ld.lld %t1.so %t.o -o %t
// RUN: llvm-objdump -s %t | FileCheck %s
// REQUIRES: arm

 .global __tls_get_addr
 .text
 .p2align  2
 .global _start
 .syntax unified
 .arm
 .type   _start, %function
_start:
.L0:
 bl __tls_get_addr

 .word   x(tlsldm) + (. - .L0 - 8)
 .word   x(tlsldo)
 .word   y(tlsldo)

 .section        .tbss,"awT",%nobits
 .p2align  2
 .type   y, %object
y:
 .space  4
 .section        .tdata,"awT",%progbits
 .p2align  2
 .type   x, %object
x:
 .word   10

// CHECK: Contents of section .got:
// CHECK-NEXT:  13064 01000000 00000000
