# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o

# RUN: not ld.lld %t1.o -o %t 2>&1 | FileCheck %s
# CHECK: .o: object file compiled with -fsplit-stack is not supported

.globl _start
_start:
 nop

.section .note.GNU-split-stack,"",@progbits
