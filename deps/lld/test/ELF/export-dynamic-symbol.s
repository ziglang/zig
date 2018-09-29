# REQUIRES: x86

# RUN: rm -f %t.a
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/archive2.s -o %t1.o
# RUN: llvm-ar rcs %t.a %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t2.o

# RUN: ld.lld -shared -o %t.so --export-dynamic-symbol foo %t.a %t2.o
# RUN: llvm-readelf -dyn-symbols %t.so | FileCheck %s

# RUN: ld.lld -shared -o %t.so --export-dynamic --export-dynamic-symbol foo %t.a %t2.o
# RUN: llvm-readelf -dyn-symbols %t.so | FileCheck %s

# CHECK: foo

.global _start
_start:
  nop
