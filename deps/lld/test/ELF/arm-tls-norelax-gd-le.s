// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %p/Inputs/arm-tls-get-addr.s -o %t1
// RUN: ld.lld %t1 --shared -o %t1.so
// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=armv7a-linux-gnueabi
// RUN: ld.lld --hash-style=sysv %t1.so %t.o -o %t
// RUN: llvm-objdump -s %t | FileCheck %s

// This tls global-dynamic sequence is with respect to a non-preemptible
// symbol in an application so a relaxation to Local Exec would normally be
// possible. This would result in an assertion failure on ARM as the
// relaxation functions can't be implemented on ARM. Check that the sequence
// is handled as global dynamic

 .text
 .syntax unified
 .globl  func
 .p2align        2
 .type   func,%function
func:
.L0:
 .globl __tls_get_addr
 bl __tls_get_addr
 bx lr
 .p2align 2
 .Lt0: .word   x(TLSGD) + (. - .L0 - 8)

 .globl  x
.section       .tbss,"awT",%nobits
 .p2align  2
x:
 .space 4
 .type  x, %object

// CHECK:       Contents of section .got:
// Module index is always 1 for executable
// CHECK-NEXT:  12060 01000000 00000000


// Without any definition of __tls_get_addr we get an error
// RUN: not ld.lld  %t.o -o %t 2>&1 | FileCheck --check-prefix=ERR %s
// ERR: error: undefined symbol: __tls_get_addr
