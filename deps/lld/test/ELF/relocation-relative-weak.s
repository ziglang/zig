# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t -pie
# RUN: llvm-readobj -dyn-relocations %t | FileCheck %s

# CHECK:      Dynamic Relocations {
# CHECK-NEXT: }

.globl _start
_start:

.globl w
.weak w
call w@PLT
