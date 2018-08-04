# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t1 --gc-sections
# RUN: llvm-objdump -section-headers -D %t1 | FileCheck %s

## Check that we are able to GC non-allocatable metadata sections without crash.

# CHECK:      Disassembly of section .stack_sizes:
# CHECK-NEXT:   .stack_sizes:
# CHECK-NEXT:    01

# CHECK:      Name          Size
# CHECK:      .stack_sizes  00000001

.section .text.live,"ax",@progbits
.globl live
live:
 nop

.section .stack_sizes,"o",@progbits,.text.live,unique,0
.byte 1

.section .text.dead,"ax",@progbits
.globl dead
dead:
 nop

.section .stack_sizes,"o",@progbits,.text.dead,unique,1
.byte 2

.section .text.main,"ax",@progbits
.globl _start
_start:
  callq live@PLT
