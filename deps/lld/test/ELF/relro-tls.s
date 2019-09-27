// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
// RUN: ld.lld %t -o %tout
// RUN: llvm-readobj -l %tout | FileCheck %s

// CHECK:      Type: PT_GNU_RELRO
// CHECK-NEXT: Offset:
// CHECK-NEXT: VirtualAddress:
// CHECK-NEXT: PhysicalAddress:
// CHECK-NEXT: FileSize: 4
// CHECK-NEXT: MemSize: 4
// CHECK-NEXT: Flags [
// CHECK-NEXT:   PF_R
// CHECK-NEXT: ]
// CHECK-NEXT: Alignment: 1

.global _start
_start:

.global d
.section .foo,"awT",@progbits
d:
.long 2
