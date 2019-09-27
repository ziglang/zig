# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=ppc64le %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-nm %t | FileCheck %s

# CHECK-DAG: 0000000010010000 t __long_branch_callee
# CHECK-DAG: 0000000010010010 T _start
# CHECK-DAG: 0000000012010008 T callee

# The bl instruction jumps to the local entry. The distance requires a long branch stub:
# localentry(callee) - _start = 0x12010008+8 - 0x10010010 = 0x2000000

# We used to compute globalentry(callee) - _start and caused a "R_PPC64_REL24
# out of range" error because we didn't create the stub.

.globl _start
_start:
  bl callee

.space 0x1fffff4

.globl callee
callee:
.Lgep0:
  addis 2, 12, .TOC.-.Lgep0@ha
  addi 2, 2, .TOC.-.Lgep0@l
.Llep0:
  .localentry callee, .Llep0-.Lgep0
  blr
