# REQUIRES: riscv
# RUN: llvm-mc -filetype=obj -triple=riscv64 %s -o %t.o
# RUN: not ld.lld -shared %t.o -o %t.so 2>&1 | FileCheck %s

# CHECK: error: relocation R_RISCV_32 cannot be used against symbol a

.globl a

.data
.long a
