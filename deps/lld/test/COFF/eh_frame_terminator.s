// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-windows-gnu %s -o %t.main.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-windows-gnu \
// RUN:   %p/Inputs/eh_frame_terminator-otherfunc.s -o %t.otherfunc.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-windows-gnu \
// RUN:   %p/Inputs/eh_frame_terminator-crtend.s -o %t.crtend.o
// RUN: rm -f %t.otherfunc.lib
// RUN: llvm-ar rcs %t.otherfunc.lib %t.otherfunc.o
// RUN: lld-link -lldmingw %t.main.o %t.otherfunc.lib %t.crtend.o -out:%t.exe
// RUN: llvm-objdump -s %t.exe | FileCheck %s

    .text
    .globl main
main:
    call otherfunc
    ret

    .globl mainCRTStartup
mainCRTStartup:
    call main

    .section .eh_frame,"dr"
    .byte 1

// CHECK: Contents of section .eh_fram:
// CHECK-NEXT: 140003000 010203
