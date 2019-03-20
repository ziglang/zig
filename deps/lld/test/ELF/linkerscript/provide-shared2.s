# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/provide-shared2.s -o %t2.o
# RUN: ld.lld %t2.o -o %t2.so -shared
# RUN: echo "SECTIONS { . = . + SIZEOF_HEADERS; PROVIDE(foo = 42); }" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o %t2.so
# RUN: llvm-readelf --dyn-symbols %t | FileCheck  %s

# CHECK: 1 1: 000000000000002a 0 NOTYPE GLOBAL DEFAULT ABS foo

.global _start
_start:
        nop
