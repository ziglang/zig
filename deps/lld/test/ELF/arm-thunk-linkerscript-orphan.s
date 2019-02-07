// REQUIRES: arm
// RUN: llvm-mc -arm-add-build-attributes -filetype=obj -triple=thumbv7a-none-linux-gnueabi %s -o %t
// RUN: echo "SECTIONS { \
// RUN:       .text_low 0x100000 : { *(.text_low) } \
// RUN:       .text_high 0x2000000 : { *(.text_high) } \
// RUN:       .data : { *(.data) } \
// RUN:       }" > %t.script
// RUN: ld.lld --script %t.script %t -o %t2 2>&1
// RUN: llvm-objdump -d -triple=thumbv7a-none-linux-gnueabi %t2 | FileCheck %s
 .syntax unified
 .section .text_low, "ax", %progbits
 .thumb
 .globl _start
_start: bx lr
 .globl low_target
 .type low_target, %function
low_target:
 bl high_target
 bl orphan_target
// CHECK: Disassembly of section .text_low:
// CHECK-NEXT: _start:
// CHECK-NEXT:   100000:        70 47   bx      lr
// CHECK: low_target:
// CHECK-NEXT:   100002:        00 f0 03 f8     bl      #6
// CHECK-NEXT:   100006:        00 f0 06 f8     bl      #12
// CHECK: __Thumbv7ABSLongThunk_high_target:
// CHECK-NEXT:   10000c:        40 f2 01 0c     movw    r12, #1
// CHECK-NEXT:   100010:        c0 f2 00 2c     movt    r12, #512
// CHECK-NEXT:   100014:        60 47   bx      r12
// CHECK: __Thumbv7ABSLongThunk_orphan_target:
// CHECK-NEXT:   100016:        40 f2 15 0c     movw    r12, #21
// CHECK-NEXT:   10001a:        c0 f2 00 2c     movt    r12, #512
// CHECK-NEXT:   10001e:        60 47   bx      r12
  .section .text_high, "ax", %progbits
 .thumb
 .globl high_target
 .type high_target, %function
high_target:
 bl low_target
 bl orphan_target
// CHECK: Disassembly of section .text_high:
// CHECK-NEXT: high_target:
// CHECK-NEXT:  2000000:        00 f0 02 f8     bl      #4
// CHECK-NEXT:  2000004:        00 f0 06 f8     bl      #12
// CHECK: __Thumbv7ABSLongThunk_low_target:
// CHECK-NEXT:  2000008:        40 f2 03 0c     movw    r12, #3
// CHECK-NEXT:  200000c:        c0 f2 10 0c     movt    r12, #16
// CHECK-NEXT:  2000010:        60 47   bx      r12

 .section orphan, "ax", %progbits
 .thumb
 .globl orphan_target
 .type orphan_target, %function
orphan_target:
 bl low_target
 bl high_target
// CHECK: Disassembly of section orphan:
// CHECK-NEXT: orphan_target:
// CHECK-NEXT:  2000014:        ff f7 f8 ff     bl      #-16
// CHECK-NEXT:  2000018:        ff f7 f2 ff     bl      #-28

 .data
 .word 10
