// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i686-unknown-cloudabi %s -o %t.o
// RUN: ld.lld --export-dynamic %t.o -o %t
// RUN: llvm-readobj -dyn-symbols %t | FileCheck %s

// Ensure that a dynamic symbol table is present when --export-dynamic
// is passed in, even when creating statically linked executables.
//
// CHECK:      DynamicSymbols [
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name:
// CHECK-NEXT:     Value: 0x0
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: Undefined
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: _start
// CHECK-NEXT:     Value: 0x11000
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text
// CHECK-NEXT:   }
// CHECK-NEXT: ]

.global _start
_start:
  ret
