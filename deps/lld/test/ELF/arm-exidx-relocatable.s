// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %S/Inputs/arm-exidx-cantunwind.s -o %tcantunwind
// Check that relocatable link maintains SHF_LINK_ORDER
// RUN: ld.lld -r %t %tcantunwind -o %t4 2>&1
// RUN: llvm-readobj -s %t4 | FileCheck %s

// Each assembler created .ARM.exidx section has the SHF_LINK_ORDER flag set
// with the sh_link containing the section index of the executable section
// containing the function it describes. To maintain this property in
// relocatable links we pass through the .ARM.exidx section, the section it
// it has a sh_link to, and the associated relocation sections uncombined.

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
 .globl f3
f3:
 .fnstart
 bx lr
 .cantunwind
 .fnend

// CHECK:         Index: 1
// CHECK-NEXT:    Name: .text

// CHECK:         Name: .ARM.exidx
// CHECK-NEXT:    Type: SHT_ARM_EXIDX (0x70000001)
// CHECK-NEXT:    Flags [ (0x82)
// CHECK-NEXT:      SHF_ALLOC (0x2)
// CHECK-NEXT:      SHF_LINK_ORDER (0x80)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address
// CHECK-NEXT:    Offset:
// CHECK-NEXT:    Size: 24
// CHECK-NEXT:    Link: 1


// CHECK:         Index: 4
// CHECK-NEXT:    Name: .text.f1

// CHECK:         Name: .ARM.exidx.text.f1
// CHECK-NEXT:    Type: SHT_ARM_EXIDX (0x70000001)
// CHECK-NEXT:    Flags [ (0x82)
// CHECK-NEXT:      SHF_ALLOC (0x2)
// CHECK-NEXT:      SHF_LINK_ORDER (0x80)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address
// CHECK-NEXT:    Offset:
// CHECK-NEXT:    Size: 8
// CHECK-NEXT:    Link: 4


// CHECK:         Index: 7
// CHECK-NEXT:    Name: .text.f2

// CHECK:         Name: .ARM.exidx.text.f2
// CHECK-NEXT:    Type: SHT_ARM_EXIDX (0x70000001)
// CHECK-NEXT:    Flags [ (0x82)
// CHECK-NEXT:      SHF_ALLOC (0x2)
// CHECK-NEXT:      SHF_LINK_ORDER (0x80)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address
// CHECK-NEXT:    Offset:
// CHECK-NEXT:    Size: 16
// CHECK-NEXT:    Link: 7


// CHECK:         Index: 10
// CHECK-NEXT:    Name: .func1

// CHECK:         Name: .ARM.exidx.func1
// CHECK-NEXT:    Type: SHT_ARM_EXIDX (0x70000001)
// CHECK-NEXT:    Flags [ (0x82)
// CHECK-NEXT:      SHF_ALLOC (0x2)
// CHECK-NEXT:      SHF_LINK_ORDER (0x80)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address
// CHECK-NEXT:    Offset:
// CHECK-NEXT:    Size: 8
// CHECK-NEXT:    Link: 10


// CHECK:         Index: 13
// CHECK-NEXT:    Name: .func2

// CHECK:         Name: .ARM.exidx.func2
// CHECK-NEXT:    Type: SHT_ARM_EXIDX (0x70000001)
// CHECK-NEXT:    Flags [ (0x82)
// CHECK-NEXT:      SHF_ALLOC (0x2)
// CHECK-NEXT:      SHF_LINK_ORDER (0x80)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address
// CHECK-NEXT:    Offset:
// CHECK-NEXT:    Size: 8
// CHECK-NEXT:    Link: 13


// CHECK:         Index: 16
// CHECK-NEXT:    Name: .func3

// CHECK:         Name: .ARM.exidx.func3
// CHECK-NEXT:    Type: SHT_ARM_EXIDX (0x70000001)
// CHECK-NEXT:    Flags [ (0x82)
// CHECK-NEXT:      SHF_ALLOC (0x2)
// CHECK-NEXT:      SHF_LINK_ORDER (0x80)
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address
// CHECK-NEXT:    Offset:
// CHECK-NEXT:    Size: 8
// CHECK-NEXT:    Link: 16
