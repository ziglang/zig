# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "SECTIONS { .foo : ALIGN(2M) {  } }" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o -shared

# We would crash if an empty section had an ALIGN.
