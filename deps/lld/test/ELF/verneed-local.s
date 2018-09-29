# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/verneed1.s -o %t1.o
# RUN: echo "v1 {}; v2 {}; v3 { local: *; };" > %t.script
# RUN: ld.lld -shared %t1.o --version-script %t.script -o %t.so

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: not ld.lld %t.o %t.so -o /dev/null 2>&1 | FileCheck %s

# CHECK: error: undefined symbol: f3
# CHECK: >>> referenced by {{.*}}:(.text+0x1)
.globl _start
_start:
call f3
