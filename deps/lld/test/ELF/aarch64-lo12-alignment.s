// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-linux %s -o %t
// RUN: not ld.lld %t -o /dev/null 2>&1 | FileCheck %s

// Test derived from a typical ODR violation where a global is declared
// extern int but defined as a half or byte sized type.
 .section .text
 .globl _start
 .type _start, %function
// Access foo2 as if it were an aligned 32-bit int, expect an error as
// foo is not aligned

_start:
 ldrb w2, [x0, #:lo12:foo1]  // Ok as no shift involved
 ldrh w2, [x0, #:lo12:foo1]  // Error foo1 is not 2-byte aligned
 ldrh w2, [x0, #:lo12:foo2]  // Ok as foo2 is 2-byte aligned
 ldr  w2, [x0, #:lo12:foo2]  // Error foo2 is not 4-byte aligned
 ldr  w2, [x0, #:lo12:foo4]  // Ok as foo4 is 4-byte aligned
 ldr  x3, [x0, #:lo12:foo4]  // Error foo4 is not 8-byte aligned
 ldr  x3, [x0, #:lo12:foo8]  // Ok as foo8 is 8-byte aligned
 ldr  q0, [x0, #:lo12:foo8]  // Error foo8 is not 16-byte aligned
 ldr  q0, [x0, #:lo12:foo16] // Ok as foo16 is 16-byte aligned

 .section .data.bool, "a", @nobits
 .balign 16
 .globl foo16
 .globl foo1
 .globl foo2
 .globl foo4
 .globl foo8
foo16:
 .space 1
foo1:
 .space 1
foo2:
 .space 2
foo4:
 .space 4
foo8:
 .space 8

// CHECK: improper alignment for relocation R_AARCH64_LDST16_ABS_LO12_NC: 0x30001 is not aligned to 2 bytes
// CHECK-NEXT: improper alignment for relocation R_AARCH64_LDST32_ABS_LO12_NC: 0x30002 is not aligned to 4 bytes
// CHECK-NEXT: improper alignment for relocation R_AARCH64_LDST64_ABS_LO12_NC: 0x30004 is not aligned to 8 bytes
// CHECK-NEXT: improper alignment for relocation R_AARCH64_LDST128_ABS_LO12_NC: 0x30008 is not aligned to 16 bytes
