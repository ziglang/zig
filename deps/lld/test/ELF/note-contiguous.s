// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o

// RUN: ld.lld %t.o -o %t1
// RUN: llvm-readobj -l %t1 | FileCheck %s

// CHECK:      Type: PT_NOTE
// CHECK-NEXT: Offset:
// CHECK-NEXT: VirtualAddress:
// CHECK-NEXT: PhysicalAddress:
// CHECK-NEXT: FileSize: 16
// CHECK-NEXT: MemSize: 16
// CHECK-NEXT: Flags [
// CHECK-NEXT:   PF_R
// CHECK-NEXT: ]
// CHECK-NEXT: Alignment: 1
// CHECK-NOT:  Type: PT_NOTE

// RUN: echo "SECTIONS { .note : { *(.note.a) *(.note.b) } }" > %t.script
// RUN: ld.lld %t.o --script %t.script -o %t2
// RUN: llvm-readobj -l %t2 | FileCheck -check-prefix=SCRIPT %s

// SCRIPT:      Type: PT_NOTE
// SCRIPT-NEXT: Offset:
// SCRIPT-NEXT: VirtualAddress:
// SCRIPT-NEXT: PhysicalAddress:
// SCRIPT-NEXT: FileSize: 16
// SCRIPT-NEXT: MemSize: 16
// SCRIPT-NEXT: Flags [
// SCRIPT-NEXT:   PF_R
// SCRIPT-NEXT: ]
// SCRIPT-NEXT: Alignment: 1
// SCRIPT-NOT:  Type: PT_NOTE

.section .note.a, "a", @note
.quad 0

.section .foo, "a"
.quad 0

.section .note.b, "a", @note
.quad 0
