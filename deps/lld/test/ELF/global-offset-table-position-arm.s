// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-linux-gnueabihf %s -o %t
// RUN: ld.lld --hash-style=sysv -shared %t -o %t2
// RUN: llvm-readobj -t %t2 | FileCheck %s

// The ARM _GLOBAL_OFFSET_TABLE_ should be defined at the start of the .got
.globl  a
.type   a,%object
.comm   a,4,4

.globl  f
.type   f,%function
f:
 ldr r2, .L1
.L0:
 add r2, pc
.L1:
.word _GLOBAL_OFFSET_TABLE_ - (.L0+4)
.word a(GOT)

.global _start
.type _start,%function
_start:
 bl f
.data

// CHECK:     Name: _GLOBAL_OFFSET_TABLE_
// CHECK-NEXT:     Value: 0x3068
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other [ (0x2)
// CHECK-NEXT:       STV_HIDDEN (0x2)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Section: .got
