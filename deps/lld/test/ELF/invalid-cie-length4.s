// REQUIRES: x86

// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
// RUN: not ld.lld %t -o /dev/null 2>&1 | FileCheck %s

.section .eh_frame
.long 0xFFFFFFFF
.byte 0

// CHECK:      error: corrupted .eh_frame: CIE/FDE too large
// CHECK-NEXT: >>> defined in {{.*}}:(.eh_frame+0x0)
