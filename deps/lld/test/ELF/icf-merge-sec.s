# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %S/Inputs/icf-merge-sec.s -o %t2
# RUN: ld.lld %t %t2 -o %t3 --icf=all --verbose | FileCheck %s

# CHECK: selected .text.f1
# CHECK:   removed .text.f2

.section .rodata.str,"aMS",@progbits,1
.asciz "foo"
.asciz "string 1"
.asciz "string 2"

.section .text.f1,"ax"
.globl f1
f1:
.quad .rodata.str
