# REQUIRES: aarch64

# RUN: llvm-mc -filetype=obj -triple=aarch64-linux-none %s -o %t.o
# RUN: ld.lld --hash-style=sysv -shared %t.o -o %t
# RUN: llvm-objdump %t -d | FileCheck %s --check-prefix=DISASM
# RUN: llvm-readelf %t --symbols | FileCheck %s --check-prefix=SYM

# It would be much easier to understand/read this test if llvm-objdump would print
# the immediates in hex.
# IMM = hex(65540) = 0x10004
# PC = 0x10000
# As the relocation is PC-relative, IMM + PC = 0x20004 which is the VA of the
# correct symbol.

# DISASM: Disassembly of section .text:
# DISASM-EMPTY:
# DISASM-NEXT: $x.0:
# DISASM-NEXT:   10000:       28 00 10 58     ldr     x8, #131076

# SYM: Symbol table '.symtab'
# SYM:  0000000000030004     0 NOTYPE  LOCAL  DEFAULT    6 patatino

  ldr x8, patatino
  .data
  .zero 4
patatino:
