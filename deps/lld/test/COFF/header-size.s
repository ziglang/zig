// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-windows %s -o %t.obj
// RUN: lld-link -entry:main -subsystem:console %t.obj -out:%t.exe
// RUN: llvm-readobj --sections %t.exe | FileCheck %s
    .globl main
main:
    ret

// Check that the first section data comes at 512 bytes in the file.
// If the size allocated for headers would include size for section
// headers which aren't written, PointerToRawData would be 0x400 instead.
// CHECK: PointerToRawData: 0x200
