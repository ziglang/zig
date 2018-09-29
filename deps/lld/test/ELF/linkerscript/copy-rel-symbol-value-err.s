# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/copy-rel-symbol-value.s -o %t2.o
# RUN: ld.lld %t2.o -o %t2.so -shared
# RUN: echo "SECTIONS { . = . + SIZEOF_HEADERS; foo = bar; }" > %t.script
# RUN: not ld.lld %t.o %t2.so --script %t.script -o /dev/null 2>&1 | FileCheck %s

# CHECK: symbol not found: bar

.global _start
_start:
.quad bar@got
