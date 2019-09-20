// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t.so -shared
// RUN: llvm-readobj --dynamic-table %t.so | FileCheck %s
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux-gnux32 %s -o %t.o
// RUN: ld.lld %t.o -o %t.so -shared
// RUN: llvm-readobj --dynamic-table %t.so | FileCheck %s

        call foo@plt

// CHECK:  0x{{0+}}14 PLTREL{{ +}}RELA
