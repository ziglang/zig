# REQUIRES: x86
# Verify that a .dynstr in the .text segment has null byte terminators

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o -no-rosegment -o %t.so -shared
# RUN: llvm-objdump %t.so -s -j .dynstr | FileCheck %s

# CHECK: 00666f6f 00 .foo.

.globl foo
foo:
    ret
