# REQUIRES: mips
# Check error message for invalid cross-mode branch instructions.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         %S/Inputs/mips-dynamic.s -o %t2.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t1.o
# RUN: not ld.lld -o %t.exe %t1.o %t2.o 2>&1 | FileCheck %s

# CHECK: (.text+0x0): unsupported jump/branch instruction between ISA modes referenced by R_MICROMIPS_PC10_S1 relocation

  .text
  .set micromips
  .global __start
__start:
  b16 foo0
