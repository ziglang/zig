// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-freebsd %s -o %t.o
// RUN: not ld.lld -shared %t.o -o /dev/null 2>&1 | FileCheck %s
// CHECK: relocation R_AARCH64_ADR_PREL_PG_HI21 cannot be used against symbol dat; recompile with -fPIC
// CHECK: >>> defined in {{.*}}.o
// CHECK: >>> referenced by {{.*}}.o:(.text+0x0)
// CHECK: relocation R_AARCH64_ADR_PREL_PG_HI21_NC cannot be used against symbol dat; recompile with -fPIC

  adrp x0, dat
  adrp x0, :pg_hi21_nc:dat
.data
.globl dat
dat:
  .word 0
