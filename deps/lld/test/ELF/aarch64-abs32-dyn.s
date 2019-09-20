# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64 %s -o %t.o
# RUN: not ld.lld -shared %t.o -o /dev/null 2>&1 | FileCheck %s

## Test we don't create R_AARCH64_RELATIVE.

# CHECK: error: relocation R_AARCH64_ABS32 cannot be used against symbol hidden; recompile with -fPIC

.globl hidden
.hidden hidden
hidden:

.data
.long hidden
