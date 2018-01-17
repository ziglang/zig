// RUN: llvm-mc -filetype=obj -triple=aarch64-linux-gnu %s -o %t
// RUN: echo "SECTIONS { \
// RUN:       .text_low : { *(.text_low) } \
// RUN:       .text_high 0x10000000 : { *(.text_high) } \
// RUN:       } " > %t.script
// RUN: ld.lld --script %t.script --shared %t -o %t2 2>&1
// RUN: llvm-objdump -d -triple=aarch64-linux-gnu %t2 | FileCheck %s
// REQUIRES: aarch64

// Check that Position Independent thunks are generated for shared libraries.
 .section .text_low, "ax", %progbits
 .globl low_target
 .type low_target, %function
low_target:
 // Need thunk to high_target@plt
 bl high_target
 ret
// CHECK: low_target:
// CHECK-NEXT:        0:        04 00 00 94     bl      #16
// CHECK-NEXT:        4:        c0 03 5f d6     ret

 .hidden low_target2
 .globl low_target2
 .type low_target2, %function
low_target2:
 // Need thunk to high_target
 bl high_target2
 ret
// CHECK: low_target2:
// CHECK-NEXT:        8:        05 00 00 94     bl      #20
// CHECK-NEXT:        c:        c0 03 5f d6     ret

// Expect range extension thunks for .text_low
// adrp calculation is (PC + signed immediate) & (!0xfff)
// CHECK: __AArch64ADRPThunk_high_target:
// CHECK-NEXT:       10:       10 00 08 90     adrp    x16, #268435456
// CHECK-NEXT:       14:       10 82 04 91     add     x16, x16, #288
// CHECK-NEXT:       18:       00 02 1f d6     br      x16
// CHECK: __AArch64ADRPThunk_high_target2:
// CHECK-NEXT:       1c:       10 00 08 90     adrp    x16, #268435456
// CHECK-NEXT:       20:       10 22 00 91     add     x16, x16, #8
// CHECK-NEXT:       24:       00 02 1f d6     br      x16


 .section .text_high, "ax", %progbits
 .globl high_target
 .type high_target, %function
high_target:
 // No thunk needed as we can reach low_target@plt
 bl low_target
 ret
// CHECK: high_target:
// CHECK-NEXT: 10000000:        4c 00 00 94     bl      #304
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
// CHECK-NEXT: 10000014:	10 22 00 91 	add	x16, x16, #8
// CHECK-NEXT: 10000018:	00 02 1f d6 	br	x16

// CHECK: Disassembly of section .plt:
// CHECK-NEXT: .plt:
// CHECK-NEXT: 10000100:        f0 7b bf a9     stp     x16, x30, [sp, #-16]!
// CHECK-NEXT: 10000104:        10 00 00 90     adrp    x16, #0
// CHECK-NEXT: 10000108:        11 aa 40 f9     ldr     x17, [x16, #336]
// CHECK-NEXT: 1000010c:        10 42 05 91     add     x16, x16, #336
// CHECK-NEXT: 10000110:        20 02 1f d6     br      x17
// CHECK-NEXT: 10000114:        1f 20 03 d5     nop
// CHECK-NEXT: 10000118:        1f 20 03 d5     nop
// CHECK-NEXT: 1000011c:        1f 20 03 d5     nop
// CHECK-NEXT: 10000120:        10 00 00 90     adrp    x16, #0
// CHECK-NEXT: 10000124:        11 ae 40 f9     ldr     x17, [x16, #344]
// CHECK-NEXT: 10000128:        10 62 05 91     add     x16, x16, #344
// CHECK-NEXT: 1000012c:        20 02 1f d6     br      x17
// CHECK-NEXT: 10000130:        10 00 00 90     adrp    x16, #0
// CHECK-NEXT: 10000134:        11 b2 40 f9     ldr     x17, [x16, #352]
// CHECK-NEXT: 10000138:        10 82 05 91     add     x16, x16, #352
// CHECK-NEXT: 1000013c:        20 02 1f d6     br      x17
