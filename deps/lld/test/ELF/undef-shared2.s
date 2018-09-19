# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/undef-shared2.s -o %t2.o
# RUN: not ld.lld %t.o %t2.o -o %t.so -shared 2>&1 | FileCheck %s
# RUN: not ld.lld %t2.o %t.o -o %t.so -shared 2>&1 | FileCheck %s

# CHECK: error: undefined symbol: foo

.data
.quad foo
.protected foo
