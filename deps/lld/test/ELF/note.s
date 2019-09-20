// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t -shared
// RUN: llvm-readobj -l %t | FileCheck %s

// CHECK:      Type: PT_NOTE
// CHECK-NEXT: Offset:
// CHECK-NEXT: VirtualAddress:
// CHECK-NEXT: PhysicalAddress:
// CHECK-NEXT: FileSize:        8
// CHECK-NEXT: MemSize:         8
// CHECK-NEXT:   Flags [
// CHECK-NEXT:   PF_R
// CHECK-NEXT: ]
// CHECK-NEXT: Alignment:       1

        .section        .note.test,"a",@note
        .quad 42
