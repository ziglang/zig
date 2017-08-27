# Check reading addends for relocations in non-allocatable sections.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         %S/Inputs/mips-nonalloc.s -o %t2.o
# RUN: ld.lld %t1.o %t2.o -o %t.exe
# RUN: llvm-objdump -s %t.exe | FileCheck %s

# REQUIRES: mips

# CHECK:      Contents of section .debug_info:
# CHECK-NEXT:  0000 ffffffff 00020000 00020000
#                            ^--------^-- __start

  .global __start
__start:
  nop

.section .debug_info
  .word 0xffffffff
  .word __start
