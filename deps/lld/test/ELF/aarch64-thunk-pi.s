// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-linux-gnu %s -o %t
// RUN: echo "SECTIONS { \
// RUN:       .text_low : { *(.text_low) } \
// RUN:       .text_high 0x10000000 : { *(.text_high) } \
// RUN:       } " > %t.script
// RUN: ld.lld --script %t.script --shared %t -o %t2 2>&1
// RUN: llvm-objdump -d -triple=aarch64-linux-gnu %t2 | FileCheck %s

// Check that Position Independent thunks are generated for shared libraries.
 .section .text_low, "ax", %progbits
 .globl low_target
 .type low_target, %function
low_target:
 // Need thunk to high_target@plt
 bl high_target
 ret
// CHECK: low_target:
// CHECK-NEXT:        8:        04 00 00 94     bl      #16
// CHECK-NEXT:        c:        c0 03 5f d6     ret

 .hidden low_target2
 .globl low_target2
 .type low_target2, %function
low_target2:
 // Need thunk to high_target
 bl high_target2
 ret
// CHECK: low_target2:
// CHECK-NEXT:        0:        05 00 00 94     bl      #20
// CHECK-NEXT:        4:        c0 03 5f d6     ret

// Expect range extension thunks for .text_low
// adrp calculation is (PC + signed immediate) & (!0xfff)
// CHECK: __AArch64ADRPThunk_high_target:
// CHECK-NEXT:       e8:       10 00 08 90     adrp    x16, #268435456
// CHECK-NEXT:       ec:       10 02 01 91     add     x16, x16, #64
// CHECK-NEXT:       f0:       00 02 1f d6     br      x16
// CHECK: __AArch64ADRPThunk_high_target2:
// CHECK-NEXT:       f4:       10 00 08 90     adrp    x16, #268435456
// CHECK-NEXT:       f8:       10 22 00 91     add     x16, x16, #8
// CHECK-NEXT:       fc:       00 02 1f d6     br      x16


 .section .text_high, "ax", %progbits
 .globl high_target
 .type high_target, %function
high_target:
 // No thunk needed as we can reach low_target@plt
 bl low_target
 ret
// CHECK: high_target:
// CHECK-NEXT: 10000000:        14 00 00 94     bl #80
// CHECK-NEXT: 10000004:        c0 03 5f d6     ret

 .hidden high_target2
 .globl high_target2
 .type high_target2, %function
high_target2:
 // Need thunk to low_target
 bl low_target2
 ret
// CHECK: high_target2:
// CHECK-NEXT: 10000008:        02 00 00 94     bl      #8
// CHECK-NEXT: 1000000c:        c0 03 5f d6     ret

// Expect Thunk for .text.high

// CHECK: __AArch64ADRPThunk_low_target2:
// CHECK-NEXT: 10000010:	10 00 f8 90 	adrp	x16, #-268435456
// CHECK-NEXT: 10000014:	10 82 03 91 	add	x16, x16, #224
// CHECK-NEXT: 10000018:	00 02 1f d6 	br	x16

// CHECK: Disassembly of section .plt:
// CHECK-NEXT: .plt:
// CHECK-NEXT: 10000020:       f0 7b bf a9     stp     x16, x30, [sp, #-16]!
// CHECK-NEXT: 10000024:       10 00 00 90     adrp    x16, #0
// CHECK-NEXT: 10000028:       11 3a 40 f9     ldr     x17, [x16, #112]
// CHECK-NEXT: 1000002c:       10 c2 01 91     add     x16, x16, #112
// CHECK-NEXT: 10000030:       20 02 1f d6     br      x17
// CHECK-NEXT: 10000034:       1f 20 03 d5     nop
// CHECK-NEXT: 10000038:       1f 20 03 d5     nop
// CHECK-NEXT: 1000003c:       1f 20 03 d5     nop
// CHECK-EMPTY:
// CHECK-NEXT:   high_target@plt:
// CHECK-NEXT: 10000040:       10 00 00 90     adrp    x16, #0
// CHECK-NEXT: 10000044:       11 3e 40 f9     ldr     x17, [x16, #120]
// CHECK-NEXT: 10000048:       10 e2 01 91     add     x16, x16, #120
// CHECK-NEXT: 1000004c:       20 02 1f d6     br      x17
// CHECK-EMPTY:
// CHECK-NEXT:   low_target@plt:
// CHECK-NEXT: 10000050:       10 00 00 90     adrp    x16, #0
// CHECK-NEXT: 10000054:       11 42 40 f9     ldr     x17, [x16, #128]
// CHECK-NEXT: 10000058:       10 02 02 91     add     x16, x16, #128
// CHECK-NEXT: 1000005c:       20 02 1f d6     br      x17
