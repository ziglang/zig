// REQUIRES: aarch64

// RUN: llvm-mc -filetype=obj -triple=aarch64-linux-none %s -o %t.o

// RUN: echo "SECTIONS \
// RUN: { \
// RUN:  .text : { *(.text) *(.rodata.foo) } \
// RUN:  .rodata : { *(.rodata.bar) } \
// RUN: }" > %t.lds
// RUN: not ld.lld -T%t.lds %t.o -o %t -execute-only 2>&1 | FileCheck %s

// RUN: echo "SECTIONS \
// RUN: { \
// RUN:  .text : { *(.text) } \
// RUN:  .rodata : { *(.rodata.bar) *(.rodata.foo) } \
// RUN: }" > %t.lds
// RUN: ld.lld -T%t.lds %t.o -o %t -execute-only 2>&1

// CHECK: -execute-only does not support intermingling data and code

    br lr

.section .rodata.foo
.word 0x1
.section .rodata.bar
.word 0x2
