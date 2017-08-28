# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t.so --icf=all -shared
# RUN: llvm-objdump -t %t.so | FileCheck %s

# CHECK: zed

        .section        .foo,"ax",@progbits
        nop

        .section        .bar,"ax",@progbits
zed:
        nop
