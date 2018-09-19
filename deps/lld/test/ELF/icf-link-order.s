# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t --icf=all --print-icf-sections | count 0

.section .foo,"a",@progbits,unique,1
foo1:
.byte 1

.section .foo,"a",@progbits,unique,2
foo2:
.byte 2

.section .bar,"ao",@progbits,foo1,unique,1
.byte 3

.section .bar,"ao",@progbits,foo2,unique,2
.byte 3
