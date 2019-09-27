// RUN: ld.lld %p/Inputs/discard-merge-unnamed.o -o %t2 -shared
// RUN: llvm-readobj --symbols %t2 | FileCheck %s

// Test that the unnamed symbol is SHF_MERGE is omitted.

// CHECK:      Symbols [
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name:  (0)
// CHECK-NEXT:     Value: 0x0
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: Undefined
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: _DYNAMIC
// CHECK-NEXT:     Value: 0x2000
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other [ (0x2)
// CHECK-NEXT:       STV_HIDDEN
// CHECK-NEXT:     ]
// CHECK-NEXT:     Section: .dynamic
// CHECK-NEXT:   }
// CHECK-NEXT: ]
