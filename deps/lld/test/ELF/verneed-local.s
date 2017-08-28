# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: not ld.lld %t.o %S/Inputs/verneed1.so -o %t 2>&1 | FileCheck %s

# CHECK: error: undefined symbol: f3
# CHECK: >>> referenced by {{.*}}:(.text+0x1)
.globl _start
_start:
call f3
