# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux /dev/null -o %t.o
# RUN: ld.lld -o %t.so --script %s %t.o -shared
# RUN: llvm-readelf -S %t.so | FileCheck %s

SECTIONS {
 .foo-bar : AT(ADDR(.foo-bar)) { *(.text) }
}

# CHECK: .foo-bar
