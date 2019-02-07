# REQUIRES: mips
# Shouldn't allow the GNU hash style to be selected with the MIPS target.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t-be.o
# RUN: not ld.lld -shared -hash-style=gnu %t-be.o -o /dev/null 2>&1 | FileCheck %s

# RUN: llvm-mc -filetype=obj -triple=mipsel-unknown-linux %s -o %t-el.o
# RUN: not ld.lld -shared -hash-style=gnu %t-el.o -o /dev/null 2>&1 | FileCheck %s

# CHECK: the .gnu.hash section is not compatible with the MIPS target

  .globl  __start
__start:
  nop
