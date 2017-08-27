// REQUIRES: x86
// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=x86_64-pc-linux
// RUN: not ld.lld %t.o -o %t.so -shared 2>&1 | FileCheck %s
// CHECK: relocation-past-merge-end.s.tmp.o:(.foo): entry is past the end of the section

.data
.long .foo + 10
.section	.foo,"aM",@progbits,4
.quad 0
