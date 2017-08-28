# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: not ld.lld %t.o -o %t -z max-page-size 2>&1 | FileCheck %s
# CHECK: invalid max-page-size
# CHECK-NOT: error

.global _start
_start:
  nop
