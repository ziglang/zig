# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: echo "SECTIONS { .init_array : { *(SORT_BY_INIT_PRIORITY(.init_array.*)) } }" > %t1.script
# RUN: ld.lld --script %t1.script %t1.o -o %t2
# RUN: llvm-objdump -s %t2 | FileCheck %s

# CHECK:      Contents of section .init_array:
# CHECK-NEXT: 03020000 00000000 010405

.globl _start
_start:
  nop

.section .init_array, "aw", @init_array
  .align 8
  .byte 1
.section .init_array.100, "aw", @init_array
  .long 2
.section .init_array.5, "aw", @init_array
  .byte 3
.section .init_array, "aw", @init_array
  .byte 4
.section .init_array, "aw", @init_array
  .byte 5
