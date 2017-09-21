// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-freebsd %s -o %t.o
// RUN: not ld.lld -shared %t.o -o %t.so 2>&1 | FileCheck %s
// CHECK: can't create dynamic relocation R_AARCH64_ADR_PREL_PG_HI21 against symbol: dat
// CHECK: >>> defined in {{.*}}.o
// CHECK: >>> referenced by {{.*}}.o:(.text+0x0)

  adrp x0, dat
.data
.globl dat
dat:
  .word 0
