// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o %p/Inputs/no-symtab.o -o %t
.global _start
_start:
