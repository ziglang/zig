# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/znotext-plt-relocations-protected.s -o %t2.o
# RUN: ld.lld %t2.o -o %t2.so -shared
# RUN: not ld.lld -z notext %t.o %t2.so -o /dev/null 2>&1 | FileCheck %s

# CHECK:      error: cannot preempt symbol: foo
# CHECK-NEXT: >>> defined in {{.*}}2.so
# CHECK-NEXT: >>> referenced by test.cpp
# CHECK-NEXT: >>>               {{.*}}.o:(.text+0x0)

.file "test.cpp"

.global _start
_start:
 .long foo - .
