// RUN: llvm-mc -filetype=obj -triple=aarch64-linux-gnu %s -o %t
// RUN: ld.lld --hash-style=sysv -shared %t -o %t2
// RUN: llvm-readobj -t %t2 | FileCheck %s
// REQUIRES: aarch64
.globl  a
.type   a,@object
.comm   a,4,4

.globl  f
.type   f,@function
f:
 adrp   x0, :got:a
 ldr    x0, [x0, #:got_lo12:a]

.global _start
.type _start,@function
_start:
 bl f
.data
.long _GLOBAL_OFFSET_TABLE_ - .

// CHECK: Name: _GLOBAL_OFFSET_TABLE_ (11)
// CHECK-NEXT:     Value: 0x30090
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local (0x0)
// CHECK-NEXT:     Type: None (0x0)
// CHECK-NEXT:     Other [ (0x2)
// CHECK-NEXT:       STV_HIDDEN (0x2)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Section: .got
