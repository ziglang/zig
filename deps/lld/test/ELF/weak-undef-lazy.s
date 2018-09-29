# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/weak-undef-lazy.s -o %t2.o
# RUN: rm -f %t2.a
# RUN: llvm-ar rc %t2.a %t2.o
# RUN: ld.lld %t.o %t2.a -o /dev/null --export-dynamic

        .global _start
_start:
        .weak foobar
        .quad foobar
