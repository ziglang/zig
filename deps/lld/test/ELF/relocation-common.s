# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-objdump -t -d %t | FileCheck %s

.global _start
_start:
  movl $1, sym1(%rip)

.global sym1
.comm sym1,4,4

# CHECK: 201000: {{.*}} movl    $1, 4086(%rip)
# CHECK: 0000000000202000 g     O .bss            00000004 sym1
