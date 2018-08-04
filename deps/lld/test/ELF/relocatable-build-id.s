# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: ld.lld --build-id=0xcafebabe -o %t2.o %t1.o -r
# RUN: ld.lld --build-id=0xdeadbeef -o %t.exe %t2.o
# RUN: llvm-objdump -s %t.exe | FileCheck %s

# CHECK-NOT: cafebabe
# CHECK: deadbeef

.global _start
_start:
  ret
