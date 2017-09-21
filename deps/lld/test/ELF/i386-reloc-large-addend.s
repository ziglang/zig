// REQUIRES: x86
// RUN: llvm-mc %s -o %t.o -triple i386-pc-linux-code16 -filetype=obj

// RUN: echo ".global foo; foo = 0x1" > %t1.s
// RUN: llvm-mc %t1.s -o %t1.o -triple i386-pc-linux -filetype=obj

// RUN: ld.lld -Ttext 0x7000 %t.o %t1.o -o %t
// RUN: llvm-objdump -d -triple=i386-pc-linux-code16 %t | FileCheck %s

// CHECK:        Disassembly of section .text:
// CHECK-NEXT: _start:
// CHECK-NEXT:     7000:       e9 fe 1f        jmp     8190
//                            0x1 + 0x9000 - 0x7003 == 8190
        .global _start
_start:
jmp foo + 0x9000
