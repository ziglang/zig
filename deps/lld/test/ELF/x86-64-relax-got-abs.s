// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -relax-relocations -triple=x86_64-pc-linux %s \
// RUN:   -o %t.o
// RUN: ld.lld --hash-style=sysv %t.o -o %t.so -shared
// RUN: llvm-objdump -d %t.so | FileCheck %s

// We used to fail trying to relax this into a pc relocation to an absolute
// value.

// CHECK: movq  4185(%rip), %rax

	movq    bar@GOTPCREL(%rip), %rax
        .data
        .global bar
        .hidden bar
        bar = 42
