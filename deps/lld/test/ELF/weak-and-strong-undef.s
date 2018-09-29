# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
# RUN: echo ".weak foo" | llvm-mc -filetype=obj -triple=x86_64-pc-linux - -o %t2.o
# RUN: not ld.lld %t1.o %t2.o -o %t 2>&1 | FileCheck %s
# RUN: not ld.lld %t2.o %t1.o -o %t 2>&1 | FileCheck %s

# CHECK: error: undefined symbol: foo

.long foo
.globl _start
_start:
ret
