// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-freebsd %s -o %t.o
// RUN: not ld.lld -shared %t.o -o /dev/null 2>&1 | FileCheck %s
// CHECK: can't create dynamic relocation R_AARCH64_LDST32_ABS_LO12_NC against symbol: dat in readonly segment; recompile object files with -fPIC or pass '-Wl,-z,notext' to allow text relocations in the output
// CHECK: >>> defined in {{.*}}.o
// CHECK: >>> referenced by {{.*}}.o:(.text+0x0)

  ldr s4, [x0, :lo12:dat]
.data
.globl dat
dat:
  .word 0
