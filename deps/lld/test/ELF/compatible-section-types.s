// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld -shared %t.o -o %t
// RUN: llvm-objdump -section-headers %t | FileCheck %s

// CHECK: .foo {{0*}}28

.section .foo, "aw", @progbits, unique, 1
.quad 0

.section .foo, "aw", @init_array, unique, 2
.quad 0

.section .foo, "aw", @preinit_array, unique, 3
.quad 0

.section .foo, "aw", @fini_array, unique, 4
.quad 0

.section .foo, "aw", @note, unique, 5
.quad 0
