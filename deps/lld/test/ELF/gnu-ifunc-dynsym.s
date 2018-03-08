// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld -static -export-dynamic %t.o -o %tout
// RUN: llvm-nm -U %tout | FileCheck %s
// REQUIRES: x86

// CHECK: __rela_iplt_end
// CHECK: __rela_iplt_start

.text
.type foo STT_GNU_IFUNC
.globl foo
foo:
 ret

.globl _start
_start:
 call foo
 movl $__rela_iplt_start,%edx
 movl $__rela_iplt_end,%edx
