# REQUIRES: x86

# Undefined symbols in a DSO should pull out object files from archives
# to resolve them.

# RUN: echo '.globl foo' | llvm-mc -filetype=obj -triple=x86_64-linux-gnu -o %t1.o -
# RUN: ld.lld -shared -o %t.so %t1.o

# RUN: llvm-mc -filetype=obj -triple=x86_64-linux-gnu -o %t2.o %s
# RUN: rm -f %t.a
# RUN: llvm-ar cru %t.a %t2.o
# RUN: ld.lld -o %t.exe %t.so %t.a
# RUN: llvm-nm -D %t.exe | FileCheck %s

# CHECK: T foo

.globl foo
foo:
  ret
