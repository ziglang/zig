# REQUIRES: ppc
# RUN: llvm-mc -filetype=obj -triple=powerpc %s -o %t.o
# RUN: ld.lld %t.o --defsym=a=0x1234 --defsym=b=0xbcdef -o %t
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck %s
# RUN: llvm-objdump -s --no-show-raw-insn %t | FileCheck --check-prefix=HEX %s

.section .R_PPC_ADDR16_HA,"ax",@progbits
  lis 4, a@ha
# CHECK-LABEL: section .R_PPC_ADDR16_HA:
# CHECK: lis 4, 0

.section .R_PPC_ADDR16_HI,"ax",@progbits
  lis 4, a@h
# CHECK-LABEL: section .R_PPC_ADDR16_HI:
# CHECK: lis 4, 0

.section .R_PPC_ADDR16_LO,"ax",@progbits
  addi 4, 4, a@l
# CHECK-LABEL: section .R_PPC_ADDR16_LO:
# CHECK: addi 4, 4, 4660

.section .R_PPC_ADDR32,"a",@progbits
  .long a
  .long b
# HEX-LABEL: section .R_PPC_ADDR32:
# HEX-NEXT: 100000b4 00001234 000bcdef
