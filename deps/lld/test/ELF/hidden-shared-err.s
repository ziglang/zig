# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/hidden-shared-err.s -o %t2.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/hidden-shared-err2.s -o %t3.o

# RUN: ld.lld -shared -o %t2.so %t2.o
# RUN: not ld.lld %t.o %t2.so -o %t 2>&1 | FileCheck %s
# RUN: not ld.lld %t2.so %t.o -o %t 2>&1 | FileCheck %s

# RUN: not ld.lld %t.o %t3.o %t2.so -o %t 2>&1 | FileCheck %s
# RUN: not ld.lld %t3.o %t.o %t2.so -o %t 2>&1 | FileCheck %s

# CHECK: undefined symbol: foo

.global _start
_start:
.quad foo
.hidden foo
