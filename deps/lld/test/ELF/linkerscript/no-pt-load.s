# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "PHDRS {foo PT_DYNAMIC ;} " \
# RUN:      "SECTIONS { .text : { *(.text) } : foo }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t.o
