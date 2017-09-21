# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld --gc-sections %t.o -o %t
# RUN: llvm-objdump -section-headers %t | FileCheck %s

# CHECK: .foo
# CHECK: .bar
# CHECK: .zed

.globl _start
_start:
.quad .foo

.section .foo,"a"
.quad 0
.section .bar,"ao",@progbits,.foo
.quad 0
.section .zed,"ao",@progbits,.foo
.quad 0
