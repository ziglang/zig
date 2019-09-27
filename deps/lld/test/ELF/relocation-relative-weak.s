# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/dummy-shared.s -o %t1.o
# RUN: ld.lld %t1.o -shared -o %t1.so
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o %t1.so -o %t -pie
# RUN: llvm-readobj --dyn-relocations %t | FileCheck %s

# CHECK:      Dynamic Relocations {
# CHECK-NEXT:   0x3018 R_X86_64_JUMP_SLOT w 0x0
# CHECK-NEXT: }

.globl _start
_start:

.globl w
.weak w
call w@PLT
