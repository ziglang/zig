// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
// RUN: ld.lld %t -o %t2
// RUN: llvm-readobj --sections %t2 | FileCheck %s

// Test that bss takes no space on disk.

// CHECK:        Name: .bss
// CHECK-NEXT:   Type: SHT_NOBITS
// CHECK-NEXT:   Flags [
// CHECK-NEXT:     SHF_ALLOC
// CHECK-NEXT:     SHF_WRITE
// CHECK-NEXT:   ]
// CHECK-NEXT:   Address:
// CHECK-NEXT:   Offset: 0x[[OFFSET:.*]]
// CHECK-NEXT:   Size: 4
// CHECK-NEXT:   Link: 0
// CHECK-NEXT:   Info: 0
// CHECK-NEXT:   AddressAlignment:
// CHECK-NEXT:   EntrySize: 0
// CHECK-NEXT: }
// CHECK-NEXT: Section {
// CHECK-NEXT:   Index:
// CHECK-NEXT:   Name:
// CHECK-NEXT:   Type:
// CHECK-NEXT:   Flags [
// CHECK-NEXT:     SHF_MERGE
// CHECK-NEXT:     SHF_STRINGS
// CHECK-NEXT:   ]
// CHECK-NEXT: Address:
// CHECK-NEXT: Offset: 0x[[OFFSET]]

        .global _start
_start:

        .bss
        .zero 4
