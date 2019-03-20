// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i386-linux-gnu %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=i386-linux-gnu %p/Inputs/i386-linkonce.s -o %t2.o
// RUN: llvm-ar rcs %t2.a %t2.o
// RUN: ld.lld %t.o %t2.a -o %t

    .globl _start
_start:
    call _strchr1
