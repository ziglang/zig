# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld %t -o /dev/null --icf=all --icf=none --verbose 2>&1 | FileCheck %s

# CHECK-NOT: selected section '.text.f1'

.globl _start, f1, f2
_start:
  ret

.section .text.f1, "ax"
f1:
  mov $60, %rax
  mov $42, %rdi
  syscall

.section .text.f2, "ax"
f2:
  mov $60, %rax
  mov $42, %rdi
  syscall
