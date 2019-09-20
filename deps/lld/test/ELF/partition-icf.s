// REQUIRES: x86
// RUN: llvm-mc %s -o %t.o -filetype=obj --triple=x86_64-unknown-linux
// RUN: ld.lld %t.o -o %t --export-dynamic --gc-sections --icf=all
// RUN: llvm-readelf -S -s %t | FileCheck %s

// CHECK: [[MAIN:[0-9]+]]] .text
// CHECK: [[P1:[0-9]+]]] .text
// CHECK: [[P2:[0-9]+]]] .text

// CHECK: Symbol table '.symtab'
// CHECK:   [[P1]] f1
// CHECK:   [[P2]] f2
// CHECK: [[MAIN]] g1
// CHECK: [[MAIN]] g2

.section .llvm_sympart.f1,"",@llvm_sympart
.asciz "part1"
.quad f1

.section .llvm_sympart.f2,"",@llvm_sympart
.asciz "part2"
.quad f2

.section .llvm_sympart.g1,"",@llvm_sympart
.asciz "part1"
.quad g1

.section .llvm_sympart.g2,"",@llvm_sympart
.asciz "part2"
.quad g2

.section .text.f1,"ax",@progbits
.globl f1
f1:
.byte 1

.section .text.f2,"ax",@progbits
.globl f2
f2:
.byte 2

.section .text.g1,"ax",@progbits
.globl g1
g1:
.byte 3

.section .text.g2,"ax",@progbits
.globl g2
g2:
.byte 3
