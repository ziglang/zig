// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t.o
// RUN: echo "PHDRS { ph_text PT_LOAD; } \
// RUN:       SECTIONS { \
// RUN:         . = SIZEOF_HEADERS; \
// RUN:         .text : { *(.text) } : ph_text \
// RUN:       }" > %t.script
// RUN: ld.lld -T %t.script %t.o -shared -o %t.so
// RUN: llvm-readobj --program-headers %t.so | FileCheck %s

// CHECK: Type: PT_ARM_EXIDX

.fnstart
bx      lr
.cantunwind
.fnend
