# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "SECTIONS { .rw : { *(.rw) } .text : { *(.text) } }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -private-headers %t1 | FileCheck %s

## We expect 2 PT_LOAD segments
# CHECK:     Program Header:
# CHECK-NEXT:  LOAD
# CHECK-NEXT:     filesz {{0x[0-9a-f]+}} memsz {{0x[0-9a-f]+}} flags rw-
# CHECK-NEXT:  LOAD
# CHECK-NEXT:     filesz {{0x[0-9a-f]+}} memsz {{0x[0-9a-f]+}} flags r-x
# CHECK-NEXT:  STACK
# CHECK-NEXT:     filesz

.globl _start
_start:
  jmp _start

.section .rw, "aw"
 .quad 0
