// REQUIRES: x86

// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: ld.lld -pie --pack-dyn-relocs=relr %t.o -o %t
// RUN: llvm-readobj --sections %t | FileCheck %s

.global _start
_start:
  nop

# CHECK-NOT: Name: .relr.dyn
