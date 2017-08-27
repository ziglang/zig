# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { \
# RUN:        . = . + 4; \
# RUN:        .text : { \
# RUN:          *(.text) \
# RUN:          foo1 = ADDR(.text) + 1; bar1 = 1 + ADDR(.text); \
# RUN:          foo2 = ADDR(.text) & 1; bar2 = 1 & ADDR(.text); \
# RUN:          foo3 = ADDR(.text) | 1; bar3 = 1 | ADDR(.text); \
# RUN:        } \
# RUN: };" > %t.script
# RUN: ld.lld -o %t.so --script %t.script %t.o -shared
# RUN: llvm-objdump -t -h %t.so | FileCheck %s

# CHECK:  1 .text         00000000 0000000000000004 TEXT DATA

# CHECK: 0000000000000005         .text		 00000000 foo1
# CHECK: 0000000000000005         .text		 00000000 bar1
# CHECK: 0000000000000000         .text		 00000000 foo2
# CHECK: 0000000000000000         .text		 00000000 bar2
# CHECK: 0000000000000005         .text		 00000000 foo3
# CHECK: 0000000000000005         .text		 00000000 bar3
