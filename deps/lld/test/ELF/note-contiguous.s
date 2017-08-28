// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: echo "SECTIONS { \
// RUN:  .note : { *(.note.a) *(.note.b) } \
// RUN: }" > %t.script
// RUN: ld.lld %t.o --script %t.script -o %t
// RUN: llvm-readobj -program-headers %t | FileCheck %s

// CHECK:      Type: PT_NOTE
// CHECK-NEXT: Offset: 0x1000
// CHECK-NEXT: VirtualAddress: 0x0
// CHECK-NEXT: PhysicalAddress: 0x0
// CHECK-NEXT: FileSize: 16
// CHECK-NEXT: MemSize: 16
// CHECK-NEXT:   Flags [
// CHECK-NEXT:   PF_R
// CHECK-NEXT: ]
// CHECK-NEXT: Alignment: 1

.section .note.a, "a", @note
.quad 0

.section .note.b, "a", @note
.quad 0
