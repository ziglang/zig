# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld %t -o %t2 --icf=all --verbose | FileCheck %s
# RUN: llvm-objdump -t %t2 | FileCheck -check-prefix=ALIGN %s

# CHECK: selected .text.f1
# CHECK:   removed .text.f2

# ALIGN: 0000000000201000 .text 00000000 _start
# ALIGN: 0000000000201100 .text 00000000 f1

.globl _start, f1, f2
_start:
  ret

.section .text.f1, "ax"
  .align 1
f1:
  mov $60, %rax
  mov $42, %rdi
  syscall

.section .text.f2, "ax"
  .align 256
f2:
  mov $60, %rax
  mov $42, %rdi
  syscall
