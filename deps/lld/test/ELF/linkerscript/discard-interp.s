// RUN: llvm-mc -filetype=obj -triple=i686-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=i686-unknown-linux %p/../Inputs/shared.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so
// RUN: echo "PHDRS { text PT_LOAD FILEHDR PHDRS; } \
// RUN:       SECTIONS { . = SIZEOF_HEADERS; .text : { *(.text) } : text }" > %t.script
// RUN: ld.lld -dynamic-linker /lib64/ld-linux-x86-64.so.2 -rpath foo -rpath bar --script %t.script --export-dynamic %t.o %t2.so -o %t
// RUN: llvm-readobj -s %t | FileCheck %s

// CHECK-NOT:        Name: .interp

.global _start
_start:
