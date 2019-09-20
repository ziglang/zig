# REQUIRES: ppc
# RUN: llvm-mc -filetype=obj -triple=powerpc %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck %s

.section .R_PPC_REL14,"ax",@progbits
  beq 1f
1:
# CHECK-LABEL: section .R_PPC_REL14:
# CHECK: bt 2, .+4

.section .R_PPC_REL24,"ax",@progbits
  b 1f
1:
# CHECK-LABEL: section .R_PPC_REL24:
# CHECK: b .+4

.section .R_PPC_REL32,"ax",@progbits
  .long 1f - .
1:
# HEX-LABEL: section .R_PPC_REL32:
# HEX-NEXT: 10010008 00000004

.section .R_PPC_PLTREL24,"ax",@progbits
  b 1f@PLT+32768
1:
# CHECK-LABEL: section .R_PPC_PLTREL24:
# CHECK: b .+4

.section .R_PPC_LOCAL24PC,"ax",@progbits
  b 1f@local
1:
# CHECK-LABEL: section .R_PPC_LOCAL24PC:
# CHECK: b .+4
