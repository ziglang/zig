# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o - > %t1
# RUN: llvm-objdump -d %t1 | FileCheck %s

# CHECK: 0000000000201000 _start:
# CHECK: 201000: 90 nop

# RUN: ld.lld %t.o -o %t2
# RUN: diff %t1 %t2

.globl _start
_start:
  nop
