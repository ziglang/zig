# REQUIRES: x86

# RUN: echo '.globl a; .type a, @function; .type a, @function; a: ret' | \
# RUN:   llvm-mc -filetype=obj -triple=x86_64-unknown-linux - -o %ta.o
# RUN: ld.lld %ta.o --shared --soname=a.so -o %ta.so

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o --as-needed %ta.so -o %t
# RUN: llvm-readelf -d %t | FileCheck %s
# RUN: ld.lld %t.o --as-needed %ta.so --gc-sections -o %t
# RUN: llvm-readelf -d %t | FileCheck %s

# The order of %ta.so and %t.o does not matter.

# RUN: ld.lld --as-needed %ta.so %t.o -o %t
# RUN: llvm-readelf -d %t | FileCheck %s
# RUN: ld.lld --as-needed %ta.so %t.o --gc-sections -o %t
# RUN: llvm-readelf -d %t | FileCheck %s

# CHECK: a.so

.global _start
_start:
  jmp a@PLT
