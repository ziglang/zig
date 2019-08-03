// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux -save-temp-labels %s -o %t
// RUN: ld.lld -discard-locals %t -o %t2
// RUN: llvm-readobj -S --section-data --symbols %t2 | FileCheck %s

.global _start
_start:

.text
.Lmyvar:
.Lmyothervar:

// CHECK:   Section {
// CHECK:     Name: .strtab
// CHECK-NEXT:     Type: SHT_STRTAB
// CHECK-NEXT:     Flags [
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address:
// CHECK-NEXT:     Offset:
// CHECK-NEXT:     Size:
// CHECK-NEXT:     Link:
// CHECK-NEXT:     Info:
// CHECK-NEXT:     AddressAlignment:
// CHECK-NEXT:     EntrySize:
// CHECK-NEXT:     SectionData (
// CHECK-NEXT:       0000: 005F7374 61727400                    |._start.|
// CHECK-NEXT:     )
// CHECK-NEXT:   }
// CHECK-NEXT: ]

// CHECK: Symbols [
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
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text
// CHECK-NEXT:   }
// CHECk-NEXT: ]
