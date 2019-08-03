# REQUIRES: riscv
# RUN: llvm-mc -filetype=obj -triple=riscv64 %s -o %t.o
# RUN: not ld.lld %t.o --defsym external=0 2>&1 | FileCheck %s

# CHECK: error: R_RISCV_PCREL_LO12 relocation points to an absolute symbol: external

addi sp,sp,%pcrel_lo(external)
