// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o

// RUN: ld.lld -o %t.exe %t.o -wrap=_start
// RUN: llvm-readobj --file-headers %t.exe | FileCheck %s

// CHECK: Entry: 0x201001

.global _start, __wrap__start
_start:
  nop
__wrap__start:
  nop
