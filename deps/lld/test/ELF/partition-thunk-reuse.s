// REQUIRES: arm
// RUN: llvm-mc %s -o %t.o -filetype=obj --triple=armv7-unknown-linux -arm-add-build-attributes
// RUN: ld.lld %t.o -o %t --export-dynamic --gc-sections
// RUN: llvm-nm %t | FileCheck %s

// CHECK: __Thumbv7ABSLongThunk__start
// CHECK: __Thumbv7ABSLongThunk__start

// CHECK: __Thumbv7ABSLongThunk_foo
// CHECK-NOT: __Thumbv7ABSLongThunk_foo

.thumb

.section .llvm_sympart.g1,"",%llvm_sympart
.asciz "part1"
.4byte f1

.section .llvm_sympart.g2,"",%llvm_sympart
.asciz "part2"
.4byte f2

.section .text._start,"ax",%progbits
.globl _start
_start:
bx lr
foo:
b f0
.zero 17*1048576

.section .text.f0,"ax",%progbits
.globl f0
f0:
b foo

.section .text.f1,"aw",%progbits
.globl f1
f1:
b _start
b foo

.section .text.f2,"ax",%progbits
.globl f2
f2:
b _start
b foo
