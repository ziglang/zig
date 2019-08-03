// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux -save-temp-labels %s -o %t
// RUN: ld.lld -discard-none -shared %t -o %t2
// RUN: llvm-readobj -S --section-data --symbols %t2 | FileCheck %s

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
// CHECK-NEXT:       0000: 002E4C6D 796F7468 65727661 72002E4C  |..Lmyothervar..L|
// CHECK-NEXT:       0010: 6D797661 72005F44 594E414D 494300    |myvar._DYNAMIC.|
// CHECK-NEXT:     )
// CHECK-NEXT:   }

// CHECK:   Symbol {
// CHECK-NEXT:     Name:
// CHECK-NEXT:     Value: 0x0
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: Undefined
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: .Lmyothervar
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: .Lmyvar
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text
// CHECK-NEXT:   }
