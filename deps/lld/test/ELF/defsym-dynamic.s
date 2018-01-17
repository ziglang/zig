# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld -o %t.so -shared %t.o --defsym=foo2=foo1
# RUN: llvm-readobj --dyn-symbols %t.so | FileCheck %s

# CHECK: Name: foo1
# CHECK: Name: foo2

.globl foo1
 foo1 = 0x123
