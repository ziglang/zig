// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: rm -f %t.a
// RUN: llvm-ar rcs %t.a %t.o
// RUN: not ld.lld -o /dev/null -u _start %t.a 2>&1 | FileCheck %s

// CHECK: target emulation unknown: -m or at least one .o file required

.global _start
_start:
