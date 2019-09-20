// REQUIRES: mips
// RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux %s -o %t
// RUN: ld.lld -shared %t -o %t2
// RUN: llvm-readobj --symbols %t2 | FileCheck %s

// The Mips _GLOBAL_OFFSET_TABLE_ should be defined at the start of the .got

.globl  a
.hidden a
.type   a,@object
.comm   a,4,4

.globl  f
.type   f,@function
f:
 ld      $v0,%got_page(a)($gp)
 daddiu  $v0,$v0,%got_ofst(a)

.global _start
.type _start,@function
_start:
 lw      $t0,%call16(f)($gp)
 .word _GLOBAL_OFFSET_TABLE_ - .
// CHECK:     Name: _GLOBAL_OFFSET_TABLE_ (1)
// CHECK-NEXT:     Value: 0x20000
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local (0x0)
// CHECK-NEXT:     Type: None (0x0)
// CHECK-NEXT:     Other [ (0x2)
// CHECK-NEXT:       STV_HIDDEN (0x2)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Section: .got (0x9)
