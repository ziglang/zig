// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/shared.s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/copy-in-shared.s -o %t2.o
// RUN: ld.lld -shared %t.o %t2.o -o %t.so

// ld.bfd and gold use .data.rel.ro rather than .bss.rel.ro. When a linker
// script, such as ld.bfd's internal linker script has a .data.rel.ro
// OutputSection we rename .bss.rel.ro to .data.rel.ro.bss in order to match in
// .data.rel.ro. This keeps the relro sections contiguous.

// Use the same sections and ordering as the ld.bfd internal linker script.
// RUN: echo "SECTIONS { \
// RUN: .data.rel.ro : { *(.data.rel.ro .data.rel.ro.*) } \
// RUN: .dynamic : { *(.dynamic) } \
// RUN: .got : { *(.got) } \
// RUN: .got.plt : { *(.got.plt) } \
// RUN: } " > %t.script
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t3.o
// RUN: ld.lld %t3.o %t.so -o %t --script=%t.script --print-map | FileCheck %s

// CHECK: .data.rel.ro
// CHECK-NEXT: <internal>:(.bss.rel.ro)
        .section .text, "ax", @progbits
        .global _start
        .global bar
        .global foo
_start:
        .quad bar
        .quad foo
