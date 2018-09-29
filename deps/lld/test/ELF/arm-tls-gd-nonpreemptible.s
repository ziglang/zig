// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: ld.lld %t -o %t2
// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=armv7a-linux-gnueabi
// RUN: llvm-objdump -s %t2 | FileCheck %s
// RUN: ld.lld --hash-style=sysv %t --shared -o %t3.so
// RUN: llvm-objdump -s %t3.so | FileCheck -check-prefix=CHECK-SHARED %s

// For an executable, we write the module index 1 and the offset into the TLS
// directly into the GOT. For a shared library we can only write the offset
// into the TLS directly if the symbol is non-preemptible

 .text
 .syntax unified
 .globl __tls_get_addr
 .type __tls_get_addr,%function
__tls_get_addr:
 bx lr

 .globl  _start
 .p2align        2
 .type   _start,%function
func:
.L0:
 nop
.L1:
 nop
.L2:
 nop
.L3:
 nop
 .p2align        2
// Generate R_ARM_TLS_GD32 relocations
// These can be resolved at static link time for executables as 1 is always the
// module index and the offset into tls is known at static link time
.Lt0: .word   x1(TLSGD) + (. - .L0 - 8)
.Lt1: .word   x2(TLSGD) + (. - .L1 - 8)
.Lt2: .word   x3(TLSGD) + (. - .L2 - 8)
.Lt3: .word   x4(TLSGD) + (. - .L3 - 8)
 .hidden x1
 .globl  x1
 .hidden x2
 .globl  x2
 .globl  x3
 .globl  x4

 .section       .tdata,"awT",%progbits
 .p2align  2
.TLSSTART:
 .type  x1, %object
x1:
 .word 10
 .type  x2, %object
x2:
 .word 20

 .section       .tbss,"awT",%nobits
 .p2align 2
 .type  x3, %object
x3:
 .space 4
 .type  x4, %object
x4:
 .space 4

// CHECK: Contents of section .got:
// CHECK-NEXT:  12008 01000000 00000000 01000000 04000000
// CHECK-NEXT:  12018 01000000 08000000 01000000 0c000000

// CHECK-SHARED: Contents of section .got:
// CHECK-SHARED-NEXT:  2050 00000000 00000000 00000000 04000000
// CHECK-SHARED-NEXT:  2060 00000000 00000000 00000000 00000000
