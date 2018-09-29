// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/relocation-copy.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t.so
// RUN: not ld.lld -z nocopyreloc %t.o %t.so -o /dev/null 2>&1 | FileCheck %s

// CHECK: unresolvable relocation R_X86_64_32S against symbol 'x'
// CHECK: unresolvable relocation R_X86_64_32S against symbol 'y'
// CHECK: unresolvable relocation R_X86_64_32S against symbol 'z'

.text
.global _start
_start:
movl $5, x
movl $7, y
movl $9, z
movl $x, %edx
movl $y, %edx
movl $z, %edx
