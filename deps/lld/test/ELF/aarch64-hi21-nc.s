// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-unknown-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t
// RUN: llvm-objdump -d %t | FileCheck %s

foo = . + 0x1100000000000000
// CHECK: adrp x0, #0
adrp x0, :pg_hi21_nc:foo
