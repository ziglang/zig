# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/verneed1.s -o %t1.o
# RUN: echo "v1 {}; v2 {}; v3 { local: *; };" > %t.script
# RUN: ld.lld -shared %t1.o --version-script %t.script -o %t.so

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o --as-needed %t.so -o %t
# RUN: llvm-readobj -V %t | FileCheck %s

# CHECK:       SHT_GNU_verneed {
# CHECK-NEXT:  }

.weak f1

.globl _start
_start:
.data
.quad f1
