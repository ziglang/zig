// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/shared.s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/copy-in-shared.s -o %t2.o
// RUN: ld.lld -shared %t.o %t2.o -o %t.so

// Place the .got.plt (non relro) immediately after .dynamic. This is the
// reverse order of the non-linker script case. The linker created .bss.rel.ro
// section will be placed after .got.plt causing the relro to be non-contiguous.
// RUN: echo "SECTIONS { \
// RUN: .dynamic : { *(.dynamic) } \
// RUN: .got.plt : { *(.got.plt) } \
// RUN: } " > %t.script
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t3.o

// Expect error for non-contiguous relro
// RUN: not ld.lld %t3.o %t.so -z relro -o %t --script=%t.script 2>&1 | FileCheck %s
// No error when we do not request relro.
// RUN: ld.lld %t3.o %t.so -z norelro -o %t --script=%t.script

// CHECK: error: section: .bss.rel.ro is not contiguous with other relro sections
        .section .text, "ax", @progbits
        .global _start
        .global bar
        .global foo
_start:
        .quad bar
        .quad foo

