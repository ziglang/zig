# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/gnu-ifunc-gotpcrel.s -o %t2.o
# RUN: ld.lld -shared %t2.o -o %t2.so
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o %t2.so -o %t
# RUN: llvm-readobj -dyn-relocations %t | FileCheck %s

# CHECK:      Dynamic Relocations {
# CHECK-NEXT:   0x2020B0 R_X86_64_GLOB_DAT foo 0x0
# CHECK-NEXT: }

.globl _start
_start:
mov foo@gotpcrel(%rip), %rax
