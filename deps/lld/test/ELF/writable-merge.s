// REQUIRES: x86
// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=x86_64-pc-linux
// RUN: not ld.lld %t.o -o /dev/null 2>&1 | FileCheck %s
// CHECK: writable SHF_MERGE section is not supported

.section .foo,"awM",@progbits,4
.quad 0
