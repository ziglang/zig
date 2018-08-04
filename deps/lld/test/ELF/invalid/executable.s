# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld -o %t1.exe %t.o
# RUN: not ld.lld -o /dev/null %t1.exe 2>&1 | FileCheck %s
# CHECK: unknown file type

.global _start
_start:
  ret
