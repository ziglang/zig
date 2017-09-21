# REQUIRES: aarch64

# We used to crash on this.

# RUN: llvm-mc %s -o %t.o -filetype=obj -triple=aarch64-pc-linux
# RUN: echo "SECTIONS { .ARM.exidx : { *(.foo) } }" > %t.script
# RUN: ld.lld -T %t.script %t.o -o %t
