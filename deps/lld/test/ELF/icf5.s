# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld %t -o /dev/null --icf=all --print-icf-sections 2>&1 | FileCheck -allow-empty %s

# CHECK-NOT: selected section '.text.f1'
# CHECK-NOT: selected section '.text.f2'

.globl _start, f1, f2
_start:
  ret

.section .text.f1, "ax"
f1:
  mov $0, %rax

.section .text.f2, "awx"
f2:
  mov $0, %rax
