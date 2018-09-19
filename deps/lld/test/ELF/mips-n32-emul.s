# REQUIRES: mips
# Check that LLD shows an error when N32 ABI emulation argument
# is combined with non-N32 ABI object files.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: not ld.lld -m elf32btsmipn32 %t.o -o /dev/null 2>&1 | FileCheck %s

  .text
  .global  __start
__start:
  nop

# CHECK: error: {{.*}}mips-n32-emul.s.tmp.o is incompatible with elf32btsmipn32
