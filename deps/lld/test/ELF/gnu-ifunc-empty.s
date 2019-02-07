// REQUIRES: x86

// Verifies that .rela_iplt_{start,end} point to a dummy section
// if .rela.iplt does not exist.

// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld -static %t.o -o %t.exe
// RUN: llvm-objdump -syms %t.exe | FileCheck %s

// CHECK: 0000000000200000 .text 00000000 .hidden __rela_iplt_end
// CHECK: 0000000000200000 .text 00000000 .hidden __rela_iplt_start

.globl _start
_start:
 movl $__rela_iplt_start, %edx
 movl $__rela_iplt_end, %edx
