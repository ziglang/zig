// REQUIRES: arm
// RUN: llvm-mc -arm-add-build-attributes -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: ld.lld %t -o %t2 2>&1
// RUN: llvm-readobj --symbols %t2 | FileCheck %s
// RUN: ld.lld --shared %t -o %t3 2>&1
// RUN: llvm-readobj --symbols %t3 | FileCheck -check-prefix=CHECK-PI %s

// Check that the symbols generated for Thunks have the correct symbol type
// of STT_FUNC and the correct value of bit 0 (0 for ARM 1 for Thumb)
 .syntax unified
 .section .text.thumb, "ax", %progbits
 .thumb
 .balign 0x1000
 .globl thumb_fn
 .type thumb_fn, %function
thumb_fn:
 b.w arm_fn

 .section .text.arm, "ax", %progbits
 .arm
 .balign 0x1000
 .globl arm_fn
 .type arm_fn, %function
arm_fn:
 b thumb_fn

// CHECK:     Name: __Thumbv7ABSLongThunk_arm_fn
// CHECK-NEXT:     Value: 0x12005
// CHECK-NEXT:     Size: 10
// CHECK-NEXT:    Binding: Local (0x0)
// CHECK-NEXT:    Type: Function (0x2)
// CHECK:     Name: __ARMv7ABSLongThunk_thumb_fn
// CHECK-NEXT:     Value: 0x12010
// CHECK-NEXT:     Size: 12
// CHECK-NEXT:    Binding: Local (0x0)
// CHECK-NEXT:    Type: Function (0x2)

// CHECK-PI:     Name: __ThumbV7PILongThunk_arm_fn
// CHECK-PI-NEXT:     Value: 0x2005
// CHECK-PI-NEXT:     Size: 12
// CHECK-PI-NEXT:    Binding: Local (0x0)
// CHECK-PI-NEXT:    Type: Function (0x2)
