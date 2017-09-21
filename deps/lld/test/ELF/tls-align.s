// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
// RUN: ld.lld %t -o %tout -shared
// RUN: llvm-readobj -program-headers %tout | FileCheck %s

        .section        .tbss,"awT",@nobits
        .align  8
        .long   0

// CHECK:      ProgramHeader {
// CHECK:        Type: PT_TLS
// CHECK-NEXT:   Offset:
// CHECK-NEXT:   VirtualAddress:
// CHECK-NEXT:   PhysicalAddress:
// CHECK-NEXT:   FileSize: 0
// CHECK-NEXT:   MemSize: 8
// CHECK-NEXT:   Flags [
// CHECK-NEXT:     PF_R (0x4)
// CHECK-NEXT:   ]
// CHECK-NEXT:   Alignment: 8
// CHECK-NEXT: }
