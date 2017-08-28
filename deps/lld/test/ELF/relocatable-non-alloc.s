# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %S/Inputs/relocatable-non-alloc.s -o %t2.o
# RUN: ld.lld %t2.o %t2.o -r -o %t3.o
# RUN: ld.lld %t1.o %t3.o -o %t.o | FileCheck -allow-empty %s

# CHECK-NOT:  has non-ABS reloc

.globl _start
_start:
