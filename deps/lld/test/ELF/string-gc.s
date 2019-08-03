// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t --gc-sections
// RUN: llvm-readobj --symbols %t | FileCheck %s

// CHECK:      Symbols [
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name:  (0)
// CHECK-NEXT:     Value: 0x0
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local (0x0)
// CHECK-NEXT:     Type: None (0x0)
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: Undefined (0x0)
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: s3
// CHECK-NEXT:     Value: 0x200120
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local (0x0)
// CHECK-NEXT:     Type: Object (0x1)
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .rodata (0x1)
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: s1
// CHECK-NEXT:     Value: 0x200125
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local (0x0)
// CHECK-NEXT:     Type: Object (0x1)
// CHECK-NEXT:     Other [ (0x2)
// CHECK-NEXT:       STV_HIDDEN (0x2)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Section: .rodata (0x1)
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: _start
// CHECK-NEXT:     Value: 0x201000
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Global (0x1)
// CHECK-NEXT:     Type: Function (0x2)
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text (0x2)
// CHECK-NEXT:   }
// CHECK-NEXT: ]

.text
.globl _start
.type _start,@function
_start:
movl $s1, %eax
movl $s3, %eax

.hidden s1
.type s1,@object
.section .rodata.str1.1,"aMS",@progbits,1
.globl s1
s1:
.asciz "abcd"

.hidden s2
.type s2,@object
.globl s2
s2:
.asciz "efgh"

.type s3,@object
s3:
.asciz "ijkl"

.type s4,@object
.globl s4
s4:
.asciz "mnop"
