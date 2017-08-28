# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o --as-needed %S/Inputs/verneed1.so -o %t
# RUN: llvm-readobj -V %t | FileCheck %s

# CHECK:       SHT_GNU_verneed {
# CHECK-NEXT:  }

.weak f1

.globl _start
_start:
.data
.quad f1
