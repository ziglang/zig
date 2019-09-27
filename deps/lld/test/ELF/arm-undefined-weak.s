// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: ld.lld %t -o %t2 2>&1
// RUN: llvm-objdump -triple=armv7a-none-linux-gnueabi -d %t2 | FileCheck %s

// Check that the ARM ABI rules for undefined weak symbols are applied.
// Branch instructions are resolved to the next instruction. Undefined
// Symbols in relative are resolved to the place so S - P + A = A.

 .syntax unified

 .weak target

 .text
 .global _start
_start:
// R_ARM_JUMP24
 b target
// R_ARM_CALL
 bl target
// R_ARM_CALL with exchange
 blx target
// R_ARM_MOVT_PREL
 movt r0, :upper16:target - .
// R_ARM_MOVW_PREL_NC
 movw r0, :lower16:target - .
// R_ARM_REL32
 .word target - .

// CHECK: Disassembly of section .text:
// CHECK-EMPTY:
// 69636 = 0x11004
// CHECK:         11000: {{.*}} b       #-4 <_start+0x4>
// CHECK-NEXT:    11004: {{.*}} bl      #-4 <_start+0x8>
// blx is transformed into bl so we don't change state
// CHECK-NEXT:    11008: {{.*}} bl      #-4 <_start+0xc>
// CHECK-NEXT:    1100c: {{.*}} movt    r0, #0
// CHECK-NEXT:    11010: {{.*}} movw    r0, #0
// CHECK:         11014: {{.*}} .word   0x00000000

