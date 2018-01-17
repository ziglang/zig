# RUN: llvm-mc %s -filetype=obj -triple=x86_64-pc-linux -o %t.o
# RUN: llvm-mc %p/Inputs/undefined-error.s -filetype=obj \
# RUN:    -triple=x86_64-pc-linux -o %t2.o
# RUN: ld.lld -shared %t2.o -o %t2.so
# RUN: not ld.lld %t2.so %t.o 2>&1 | FileCheck %s

# CHECK: undefined symbol: fmod
# Check we're not emitting other diagnostics for this symbol.
# CHECK-NOT: fmod

.global main

main:
  callq fmod
