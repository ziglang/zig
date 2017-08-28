# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: ld.lld -r %t1.o -o %t
# RUN: llvm-objdump -section-headers %t | FileCheck %s

# CHECK:      .text
# CHECK-NEXT: .rela.text
# CHECK: .text._init
# CHECK-NEXT: .rela.text._init
# CHECK: .text._fini
# CHECK-NEXT: .rela.text._fini

.globl _start
_start:
 call foo
 nop

.section .xxx,"a"
 .quad 0

.section .text._init,"ax"
 .quad .xxx
foo:
 call bar
 nop


.section .text._fini,"ax"
 .quad .xxx
bar:
 nop
