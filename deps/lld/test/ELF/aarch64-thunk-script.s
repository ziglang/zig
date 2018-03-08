// RUN: llvm-mc -filetype=obj -triple=aarch64-linux-gnu %s -o %t
// RUN: echo "SECTIONS { \
// RUN:       .text_low 0x2000: { *(.text_low) } \
// RUN:       .text_high 0x8002000 : { *(.text_high) } \
// RUN:       } " > %t.script
// RUN: ld.lld --script %t.script %t -o %t2 2>&1
// RUN: llvm-objdump -d -triple=aarch64-linux-gnu %t2 | FileCheck %s
// REQUIRES: aarch64

// Check that we have the out of branch range calculation right. The immediate
// field is signed so we have a slightly higher negative displacement.
 .section .text_low, "ax", %progbits
 .globl _start
 .type _start, %function
_start:
 // Need thunk to high_target@plt
 bl high_target
 ret

 .section .text_high, "ax", %progbits
 .globl high_target
 .type high_target, %function
high_target:
 // No Thunk needed as we are within signed immediate range
 bl _start
 ret

// CHECK: Disassembly of section .text_low:
// CHECK-NEXT: _start:
// CHECK-NEXT:     2000:       02 00 00 94     bl      #8
// CHECK-NEXT:     2004:       c0 03 5f d6     ret
// CHECK: __AArch64AbsLongThunk_high_target:
// CHECK-NEXT:     2008:       50 00 00 58     ldr     x16, #8
// CHECK-NEXT:     200c:       00 02 1f d6     br      x16
// CHECK: $d:
// CHECK-NEXT:     2010:       00 20 00 08     .word   0x08002000
// CHECK-NEXT:     2014:       00 00 00 00     .word   0x00000000
// CHECK: Disassembly of section .text_high:
// CHECK-NEXT: high_target:
// CHECK-NEXT:  8002000:       00 00 00 96     bl      #-134217728
// CHECK-NEXT:  8002004:       c0 03 5f d6     ret
