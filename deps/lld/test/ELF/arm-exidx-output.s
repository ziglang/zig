// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: ld.lld %t -o %t2 2>&1
// RUN: llvm-readobj -sections %t2 | FileCheck %s

// Check that only a single .ARM.exidx output section is created when
// there are input sections of the form .ARM.exidx.<section-name>. The
// assembler creates the .ARM.exidx input sections with the .cantunwind
// directive
 .syntax unified
 .section .text, "ax",%progbits
 .globl _start
_start:
 .fnstart
 bx lr
 .cantunwind
 .fnend

 .section .text.f1, "ax", %progbits
 .globl f1
f1:
 .fnstart
 bx lr
 .cantunwind
 .fnend

 .section .text.f2, "ax", %progbits
 .globl f2
f2:
 .fnstart
 bx lr
 .cantunwind
 .fnend

// CHECK:         Section {
// CHECK:         Name: .ARM.exidx
// CHECK-NEXT:    Type: SHT_ARM_EXIDX (0x70000001)
// CHECK-NEXT:    Flags [
// CHECK-NEXT:      SHF_ALLOC
// CHECK-NEXT:      SHF_LINK_ORDER
// CHECK-NEXT:    ]

// CHECK-NOT:     Name: .ARM.exidx.text.f1
// CHECK-NOT:     Name: .ARM.exidx.text.f2
