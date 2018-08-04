# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %S/Inputs/icf-absolute2.s -o %t2
# RUN: ld.lld %t %t2 -o /dev/null --icf=all --print-icf-sections | FileCheck -allow-empty %s

## Test we do not crash and do not fold sections which relocations reffering to
## absolute symbols with a different values.
# CHECK-NOT: selected

.globl _start, f1, f2
_start:
  ret

.section .text.f1, "ax"
f1:
  .byte a1

.section .text.f2, "ax"
f2:
  .byte a2
