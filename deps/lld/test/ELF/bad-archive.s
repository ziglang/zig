// REQUIRES: x86

// Check bad archive error reporting with --whole-archive
// and without it.
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: not ld.lld %t.o %p/Inputs/bad-archive.a -o %t 2>&1 | FileCheck %s
// RUN: not ld.lld %t.o --whole-archive %p/Inputs/bad-archive.a -o %t 2>&1 | FileCheck %s
// CHECK: bad-archive.a: failed to parse archive

.globl _start
_start:
