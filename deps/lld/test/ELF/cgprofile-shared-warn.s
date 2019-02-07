# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld --shared %t.o -o /dev/null 2>&1 | count 0
# RUN: ld.lld -e A --unresolved-symbols=ignore-all %t.o -o /dev/null 2>&1 | count 0

# RUN: echo '.globl B; B: ret' | llvm-mc -filetype=obj -triple=x86_64-unknown-linux - -o %t1.o
# RUN: ld.lld --shared %t1.o -o %t1.so
# RUN: ld.lld -e A %t.o %t1.so -o /dev/null 2>&1 | count 0

# RUN: ld.lld --gc-sections %t.o %t1.so -o /dev/null 2>&1 | count 0
.globl _start
_start:
  ret

.section .text.A,"ax",@progbits
.globl A
A:
  callq B

.cg_profile A, B, 10
