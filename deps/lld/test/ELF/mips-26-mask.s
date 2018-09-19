# REQUIRES: mips
# Check reading/writing implicit addend for R_MIPS_26 relocation.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t.exe
# RUN: llvm-objdump -d %t.exe | FileCheck %s

# CHECK:      Disassembly of section .text:
# CHECK:      __start:
# CHECK-NEXT:   20000:       0e 00 80 00     jal     134348800

  .text
  .global __start
__start:
  jal __start+0x8000000
