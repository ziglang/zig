// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t -shared
// RUN: llvm-readobj -program-headers -sections %t | FileCheck %s

// PR37361: A note without SHF_ALLOC should not be included into a PT_NOTE program header.

// CHECK:      Section {
// CHECK:        Index:
// CHECK:        Name: .note.a
// CHECK-NEXT:   Type: SHT_NOTE
// CHECK-NEXT:   Flags [
// CHECK-NEXT:     SHF_ALLOC
// CHECK-NEXT:   ]
// CHECK-NEXT:   Address: 0x[[ADDR:.*]]

// Check we still emit the non-alloc SHT_NOTE section and keep its type.

// CHECK:        Name: .note.b
// CHECK-NEXT:   Type: SHT_NOTE
// CHECK-NEXT:   Flags [
// CHECK-NEXT:   ]

// CHECK:      ProgramHeader {
// CHECK:        Type: PT_NOTE
// CHECK-NEXT:   Offset:
// CHECK-NEXT:   VirtualAddress: 0x[[ADDR]]
// CHECK-NEXT:   PhysicalAddress: 0x[[ADDR]]
// CHECK-NEXT:   FileSize: 16
// CHECK-NEXT:   MemSize: 16
// CHECK-NOT:  PT_NOTE

.section        .note.a,"a",@note
.quad 1
.quad 2

.section        .note.b,"",@note
.quad 3
