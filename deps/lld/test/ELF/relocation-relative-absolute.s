# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %tinput1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux \
# RUN:   %S/Inputs/relocation-relative-absolute.s -o %tinput2.o
# RUN: not ld.lld %tinput1.o %tinput2.o -o /dev/null -pie 2>&1 | FileCheck %s

.globl _start
_start:

# CHECK:      error: relocation R_X86_64_PLT32 cannot refer to absolute symbol: answer
# CHECK-NEXT: >>> defined in {{.*}}input2.o
# CHECK-NEXT: >>> referenced by {{.*}}o:(.text+0x1)

call answer@PLT
