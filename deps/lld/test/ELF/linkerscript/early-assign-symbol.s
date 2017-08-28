# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o

# RUN: echo "SECTIONS { aaa = 1 + ABSOLUTE(foo - 1); .text  : { *(.text*) } }" > %t1.script
# RUN: not ld.lld -o %t --script %t1.script %t.o 2>&1 | FileCheck %s

# RUN: echo "SECTIONS { aaa = ABSOLUTE(foo - 1) + 1; .text  : { *(.text*) } }" > %t2.script
# RUN: not ld.lld -o %t --script %t2.script %t.o 2>&1 | FileCheck %s

# CHECK: error: {{.*}}.script:1: unable to evaluate expression: input section .text has no output section assigned

.section .text
.globl foo
foo:
