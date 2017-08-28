# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1
# RUN: rm -f %t.a
# RUN: llvm-ar rcs %t.a %t1
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/symver-archive1.s -o %t2.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/symver-archive2.s -o %t3.o
# RUN: ld.lld -o %t.out %t2.o %t3.o %t.a

.text
.globl x
.type x, @function
x:

.globl xx
xx = x
