# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/shared.s -o %t2.o
# RUN: ld.lld -shared %t2.o -o %t2.so

# RUN: echo "SECTIONS { }" > %t.script
# RUN: ld.lld %t1.o %t2.so -o %t
# RUN: llvm-readobj --dynamic-table %t | FileCheck %s

# CHECK:      DynamicSection [
# CHECK-NEXT:  Tag                 Type             Name/Value
# CHECK:       0x0000000000000021  PREINIT_ARRAYSZ  9 (bytes)
# CHECK:       0x000000000000001B  INIT_ARRAYSZ     8 (bytes)
# CHECK:       0x000000000000001C  FINI_ARRAYSZ     10 (bytes)

.globl _start
_start:

.section .init_array,"aw",@init_array
  .quad 0

.section .preinit_array,"aw",@preinit_array
  .quad 0
  .byte 0

.section .fini_array,"aw",@fini_array
  .quad 0
  .short 0
