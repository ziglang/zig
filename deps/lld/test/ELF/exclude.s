# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld -o %t1 %t
# RUN: llvm-objdump -section-headers %t1 | FileCheck %s
# RUN: ld.lld -r -o %t1 %t
# RUN: llvm-objdump -section-headers %t1 | FileCheck --check-prefix=RELOCATABLE %s

# CHECK-NOT:      .aaa
# RELOCATABLE:    .aaa

.globl _start
_start:
  jmp _start

.section .aaa,"ae"
 .quad .bbb

.section .bbb,"a"
 .quad 0
