# REQUIRES: mips
# Check the order of dynamic symbols for the MIPS target.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t-be.o
# RUN: ld.lld -shared %t-be.o -o %t-be.so
# RUN: llvm-readobj -symbols -dyn-symbols %t-be.so | FileCheck %s

# RUN: llvm-mc -filetype=obj -triple=mipsel-unknown-linux %s -o %t-el.o
# RUN: ld.lld -shared %t-el.o -o %t-el.so
# RUN: llvm-readobj -symbols -dyn-symbols %t-el.so | FileCheck %s

  .data
  .globl v1,v2,v3
v1:
  .space 4
v2:
  .space 4
v3:
  .space 4

  .text
  .globl  __start
__start:
  lui $2, %got(v3) # v3 will precede v1 in the GOT
  lui $2, %got(v1)

# Since all these symbols have global binding,
# the Symbols section contains them in the original order.
# CHECK: Symbols [
# CHECK:     Name: v1
# CHECK:     Name: v2
# CHECK:     Name: v3
# CHECK: ]

# The symbols in the DynamicSymbols section are sorted in compliance with
# the MIPS rules. v2 comes first as it is not in the GOT.
# v1 and v3 are sorted according to their order in the GOT.
# CHECK: DynamicSymbols [
# CHECK:     Name: v2
# CHECK:     Name: v3
# CHECK:     Name: v1
# CHECK: ]
