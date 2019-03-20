// REQUIRES: x86
// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=x86_64-pc-linux
// RUN: not ld.lld %t.o -o /dev/null -shared 2>&1 | FileCheck %s
// CHECK: relocation-before-merge-start.s.tmp.o:(.foo): offset is outside the section

.data
.long .foo - 1
.section	.foo,"aM",@progbits,4
.quad 0
