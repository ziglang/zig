# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o

# RUN: echo "SECTIONS {                                   \
# RUN:         .foo-bar : AT(ADDR(.foo-bar)) { *(.text) } \
# RUN:       }" > %t.script
# RUN: ld.lld -o %t.so --script %t.script %t.o -shared
# RUN: llvm-readelf -S %t.so | FileCheck %s

# CHECK: .foo-bar
