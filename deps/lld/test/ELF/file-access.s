# REQUIRES: x86, shell

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld -r %t.o -o %t1.o
# RUN: [ ! -x %t1.o ]
# RUN: ld.lld -shared %t.o -o %t2.so
# RUN: [ -x %t2.so ]
# RUN: ld.lld %t.o -o %t3
# RUN: [ -x %t3 ]

.global _start
_start:
  nop
