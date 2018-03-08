# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/znotext-plt-relocations-protected.s -o %t2.o
# RUN: ld.lld %t2.o -o %t2.so -shared
# RUN: not ld.lld -z notext %t.o %t2.so -o %t 2>&1 | FileCheck %s

# CHECK: error: cannot preempt symbol: foo

.global _start
_start:
callq foo
