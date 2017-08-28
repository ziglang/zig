# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# RUN: echo "SECTIONS                                \
# RUN: {                                             \
# RUN:  . = DEFINED(defined) ? 0x11000 : .;          \
# RUN:  .foo : { *(.foo*) }                          \
# RUN:  . = DEFINED(notdefined) ? 0x12000 : 0x13000; \
# RUN:  .bar : { *(.bar*) }                          \
# RUN: }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -section-headers %t1 | FileCheck %s

# CHECK: 1 .foo  00000008 0000000000011000 DATA
# CHECK: 2 .bar  00000008 0000000000013000 DATA
# CHECK: 3 .text 00000000 0000000000013008 TEXT DATA

.global defined
defined = 0

.section .foo,"a"
.quad 1

.section .bar,"a"
.quad 1
