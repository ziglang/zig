// REQUIRES: x86
// RUN: llvm-mc %s -o %t.o -triple i386-pc-linux-code16 -filetype=obj

// RUN: echo ".global foo; foo = 0x10202" > %t1.s
// RUN: llvm-mc %t1.s -o %t1.o -triple i386-pc-linux -filetype=obj
// RUN: echo ".global foo; foo = 0x10203" > %t2.s
// RUN: llvm-mc %t2.s -o %t2.o -triple i386-pc-linux -filetype=obj

// RUN: ld.lld -Ttext 0x200 %t.o %t1.o -o %t1
// RUN: llvm-objdump -d -triple=i386-pc-linux-code16 %t1 | FileCheck %s

// CHECK:        Disassembly of section .text:
// CHECK-NEXT: _start:
// CHECK-NEXT:      200: {{.*}} jmp -1
//              0x10202 - 0x203 == 0xffff

// RUN: not ld.lld -Ttext 0x200 %t.o %t2.o -o %t2 2>&1 | FileCheck --check-prefix=ERR %s

// ERR: {{.*}}:(.text+0x1): relocation R_386_PC16 out of range: 65536 is not in [-65536, 65535]

        .global _start
_start:
        jmp foo
