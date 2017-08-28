# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { foo = ADDR(.text) + ADDR(.text); };" > %t.script
# RUN: not ld.lld -o %t.so --script %t.script %t.o -shared 2>&1 | FileCheck %s

# CHECK: error: {{.*}}.script:1: at least one side of the expression must be absolute
