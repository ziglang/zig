# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o

# RUN: echo "SECTIONS { .bar (foo) : { } };" > %t.script
# RUN: not ld.lld -o %t --script %t.script %t.o 2>&1 | FileCheck %s
# CHECK: symbol not found: foo

# RUN: echo "SECTIONS { .bar : AT(foo) { } };" > %t.script
# RUN: not ld.lld -o %t --script %t.script %t.o 2>&1 | FileCheck %s

# RUN: echo "SECTIONS { .bar : ALIGN(foo) { } };" > %t.script
# RUN: not ld.lld -o %t --script %t.script %t.o 2>&1 | FileCheck %s

# RUN: echo "SECTIONS { .bar : SUBALIGN(foo) { } };" > %t.script
# RUN: not ld.lld -o %t --script %t.script %t.o 2>&1 | FileCheck %s
