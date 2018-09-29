# REQUIRES: aarch64

# RUN: llvm-mc -filetype=obj -triple=aarch64-linux-none %s -o %t.o
# RUN: not ld.lld -shared %t.o -o /dev/null 2>&1 | FileCheck %s

# CHECK: relocation R_AARCH64_LD_PREL_LO19 out of range: 2065536 is not in [-1048576, 1048575]

  ldr x8, patatino
  .data
  .zero 2000000
patatino:
