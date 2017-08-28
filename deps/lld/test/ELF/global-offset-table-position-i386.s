// RUN: llvm-mc -filetype=obj -triple=i386-pc-linux %s -o %t
// RUN: ld.lld -shared %t -o %t2
// RUN: llvm-readobj -t %t2 | FileCheck %s
// REQUIRES: x86

// The X86 _GLOBAL_OFFSET_TABLE_ is defined at the end of the .got section.
.globl  a
.type   a,@object
.comm   a,4,4

.globl  f
.type   f,@function
f:
addl    $_GLOBAL_OFFSET_TABLE_, %eax
movl    a@GOT(%eax), %eax

.global _start
.type _start,@function
_start:
addl    $_GLOBAL_OFFSET_TABLE_, %eax
calll   f@PLT

// CHECK:     Name: _GLOBAL_OFFSET_TABLE_ (1)
// CHECK-NEXT:     Value: 0x306C
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local (0x0)
// CHECK-NEXT:     Type: None (0x0)
// CHECK-NEXT:     Other [ (0x2)
// CHECK-NEXT:       STV_HIDDEN (0x2)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Section: .got (0xA)
