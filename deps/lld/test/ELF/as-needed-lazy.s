# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/as-needed-lazy.s -o %t2.o
# RUN: ld.lld %t2.o -o %t2.so -shared
# RUN: rm -f %t2.a
# RUN: llvm-ar rc %t2.a %t2.o
# RUN: ld.lld %t1.o %t2.a --as-needed %t2.so -o %t
# RUN: llvm-readobj -d %t | FileCheck %s

# CHECK-NOT: NEEDED

.global _start
_start:
  nop
