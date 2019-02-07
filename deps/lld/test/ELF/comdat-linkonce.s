// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/comdat.s -o %t2.o
// RUN: ld.lld -shared %t.o %t2.o -o %t
// RUN: ld.lld -shared %t2.o %t.o -o %t

.section .gnu.linkonce.t.__x86.get_pc_thunk.bx
.globl abc
abc:
nop

.section .gnu.linkonce.t.__i686.get_pc_thunk.bx
.globl def
def:
nop
