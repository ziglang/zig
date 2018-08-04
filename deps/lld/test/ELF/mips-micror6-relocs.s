# REQUIRES: mips

# Check handling of microMIPS R6 relocations.

# RUN: llvm-mc -filetype=obj -triple=mips -mcpu=mips32r6 \
# RUN:         %S/Inputs/mips-micro.s -o %t1eb.o
# RUN: llvm-mc -filetype=obj -triple=mips -mcpu=mips32r6 %s -o %t2eb.o
# RUN: ld.lld -o %teb.exe %t1eb.o %t2eb.o
# RUN: llvm-objdump -d -t -mattr=micromips %teb.exe \
# RUN:   | FileCheck --check-prefixes=EB,SYM %s

# RUN: llvm-mc -filetype=obj -triple=mipsel -mcpu=mips32r6 \
# RUN:         %S/Inputs/mips-micro.s -o %t1el.o
# RUN: llvm-mc -filetype=obj -triple=mipsel -mcpu=mips32r6 %s -o %t2el.o
# RUN: ld.lld -o %tel.exe %t1el.o %t2el.o
# RUN: llvm-objdump -d -t -mattr=micromips %tel.exe \
# RUN:   | FileCheck --check-prefixes=EL,SYM %s

# EB:      __start:
# EB-NEXT:    20010:  78 47 ff fd  lapc   $2, -12
# EB-NEXT:    20014:  80 7f ff f6  beqzc  $3, -36
# EB-NEXT:    20018:  b7 ff ff f4  balc   -24 <foo>

# EL:      __start:
# EL-NEXT:    20010:  47 78 fd ff  lapc   $2, -12
# EL-NEXT:    20014:  7f 80 f6 ff  beqzc  $3, -36
# EL-NEXT:    20018:  ff b7 f4 ff  balc   -24 <foo>

# SYM: 00020000 g F     .text           00000000 foo
# SYM: 00020010         .text           00000000 __start

  .text
  .set micromips
  .global __start
__start:
  addiupc $2, foo+4   # R_MICROMIPS_PC19_S2
  beqzc   $3, foo+4   # R_MICROMIPS_PC21_S1
  balc    foo+4       # R_MICROMIPS_PC26_S1
