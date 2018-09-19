// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
// RUN: not ld.lld %t -o /dev/null 2>&1 | FileCheck %s
// CHECK: R_X86_64_TPOFF32 out of range

.global _start
_start:
        movl %fs:a@tpoff, %eax
.global a
.section        .tbss,"awT",@nobits
a:
.zero 0x80000001
