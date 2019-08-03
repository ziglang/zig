# REQUIRES: ppc
# RUN: llvm-mc -filetype=obj -triple=powerpc %s -o %t.o
# RUN: echo '.globl foo; foo: blr' | llvm-mc -filetype=obj -triple=powerpc - -o %t1.o
# RUN: ld.lld %t.o %t1.o -o %t
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck %s

## R_PPC_REL24 and R_PPC_PLTREL24 are converted to PC relative relocations if the
## symbol is non-preemptable. The addend of R_PPC_PLTREL24 should be ignored.

# CHECK:      _start:
# CHECK-NEXT:   b .+12
# CHECK-NEXT:   b .+8
# CHECK-NEXT:   b .+4
# CHECK-EMPTY:
# CHECK-NEXT: foo:

.globl _start
_start:
  b foo  # R_PPC_REL24
  b foo@plt  # R_PPC_PLTREL24
  b foo+32768@plt  #_PPC_PLTREL24 with addend
