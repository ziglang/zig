// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-linux-gnu -save-temp-labels %s -o %t
// RUN: ld.lld %t -o %t2
// RUN: llvm-readobj -s -sd -t %t2 | FileCheck %s

.global _start
_start:

// This section and symbol is used by Linux kernel modules. Ensure it's not
// accidentally discarded.
.section .gnu.linkonce.this_module:
__this_module:
.byte 0x00

// CHECK: Section {
// CHECK:    Index:
// CHECK:    Name: .gnu.linkonce.this_module
// CHECK-NEXT:    Type: SHT_PROGBITS
// CHECK-NEXT:    Flags [
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address:
// CHECK-NEXT:    Offset:
// CHECK-NEXT:    Size:
// CHECK-NEXT:    Link:
// CHECK-NEXT:    Info:
// CHECK-NEXT:    AddressAlignment:
// CHECK-NEXT:    EntrySize:
// CHECK-NEXT:    SectionData (
// CHECK-NEXT:      0000: 00                                   |.|
// CHECK-NEXT:    )
// CHECK-NEXT:  }

// CHECK:  Symbol {
// CHECK:    Name: __this_module
// CHECK-NEXT:    Value:
// CHECK-NEXT:    Size:
// CHECK-NEXT:    Binding: Local
// CHECK-NEXT:    Type: None
// CHECK-NEXT:    Other:
// CHECK-NEXT:    Section: .gnu.linkonce.this_module:
// CHECK-NEXT:  }
