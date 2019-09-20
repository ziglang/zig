# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld --hash-style=sysv %t.o -o %t --icf=all -shared
# RUN: llvm-readelf --dyn-symbols --sections %t | FileCheck %s

# We used to mark bar as absolute.

# CHECK: .text             PROGBITS        0000000000001000
# CHECK: 0000000000001001 0 NOTYPE  GLOBAL DEFAULT   4 bar
# CHECK: 0000000000001001 0 NOTYPE  GLOBAL DEFAULT   4 foo

# The nop makes the test more interesting by making the offset of
# text.f non zero.

nop

        .section        .text.f,"ax",@progbits
        .globl  foo
foo:
        retq

        .section        .text.g,"ax",@progbits
        .globl  bar
bar:
        retq
