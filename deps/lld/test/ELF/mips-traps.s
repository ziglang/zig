# Check trap instruction encoding.

# REQUIRES: mips

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux -mcpu=mips32r6 -o %t.o %s
# RUN: ld.lld -r -o %t %t.o %t.o
# RUN: llvm-objdump -d -r %t | FileCheck --check-prefix=EB %s

# RUN: llvm-mc -filetype=obj -triple=mipsel-unknown-linux -mcpu=mips32r6 -o %t.o %s
# RUN: ld.lld -r -o %t %t.o %t.o
# RUN: llvm-objdump -d -r %t | FileCheck --check-prefix=EL %s

# EB:        8:       04 17 00 01     sigrie 1
# EL:        8:       01 00 17 04     sigrie 1

  .text
  lw     $t9, %got(.data)($gp)
  addiu  $a0, $t9, %lo(.data)

  .data
data:
  .word 0
