# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o

# Sanity check that the link will fail with the undefined error without
# gc-sections.
# RUN: not ld.lld %t.o -o %t 2>&1 | FileCheck %s
# CHECK: error: undefined symbol: undefined

# RUN: ld.lld %t.o --gc-sections -o %t

.section .text.unused,"ax",@progbits
unused:
  callq undefined

.text
.global _start
_start:
  nop
