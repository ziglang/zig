# REQUIRES: x86

### Make sure that we do not merge data.
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld %t -o %t2 --icf=all --verbose | FileCheck %s

# CHECK-NOT: selected .data.d1
# CHECK-NOT: selected .data.d2

.globl _start, d1, d2
_start:
  ret

.section .data.f1, "a"
d1:
  .byte 1

.section .data.f2, "a"
d2:
  .byte 1
