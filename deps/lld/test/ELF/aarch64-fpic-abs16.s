// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-freebsd %s -o %t.o
// RUN: not ld.lld -shared %t.o -o %t.so 2>&1 | FileCheck %s
// CHECK:      relocation R_AARCH64_ABS16 cannot be used against shared object; recompile with -fPIC
// CHECK-NEXT: >>> defined in {{.*}}.o
// CHECK-NEXT: >>> referenced by {{.*}}.o:(.data+0x0)

.data
  .hword foo
