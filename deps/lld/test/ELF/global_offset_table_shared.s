// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
// RUN: ld.lld --hash-style=sysv -shared %t -o %t2
// RUN: llvm-readobj --symbols %t2 | FileCheck %s
.long _GLOBAL_OFFSET_TABLE_ - .

// CHECK:      Name: _GLOBAL_OFFSET_TABLE_
// CHECK-NEXT: Value: 0x3000
// CHECK-NEXT: Size: 0
// CHECK-NEXT: Binding: Local
// CHECK-NEXT: Type: None
// CHECK-NEXT: Other [ (0x2)
// CHECK-NEXT: STV_HIDDEN (0x2)
// CHECK-NEXT:    ]
// CHECK-NEXT: Section: .got.plt
