// REQUIRES: arm

// RUN: llvm-mc -filetype=obj -triple=armv7-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t.so -shared
// RUN: llvm-readelf -l %t.so | FileCheck %s

// RUN: ld.lld %t.o %t.o -o %t.so -shared
// RUN: llvm-readelf -l %t.so | FileCheck %s

// RUN: echo ".section .foo,\"ax\"; \
// RUN:       bx lr" > %t.s
// RUN: llvm-mc -filetype=obj -triple=armv7-pc-linux %t.s -o %t2.o
// RUN: ld.lld %t.o %t2.o -o %t.so -shared
// RUN: llvm-readelf -l %t.so | FileCheck --check-prefix=DIFF %s

// CHECK-NOT:  LOAD
// CHECK:      LOAD           0x000000 0x00000000 0x00000000 0x0016d 0x0016d  R 0x1000
// CHECK:      LOAD           0x001000 0x00001000 0x00001000 0x{{.*}} 0x{{.*}} R E 0x1000
// CHECK:      LOAD           0x002000 0x00002000 0x00002000 0x{{.*}} 0x{{.*}}   E 0x1000
// CHECK:      LOAD           0x003000 0x00003000 0x00003000 0x00038  0x00038  RW  0x1000
// CHECK-NOT:  LOAD

// CHECK: 01     .dynsym .gnu.hash .hash .dynstr
// CHECK: 02     .text
// CHECK: 03     .foo
// CHECK: 04     .dynamic

// DIFF-NOT:  LOAD
// DIFF:      LOAD           0x000000 0x00000000 0x00000000 0x0014d 0x0014d R   0x1000
// DIFF:      LOAD           0x001000 0x00001000 0x00001000 0x0000c 0x0000c R E 0x1000
// DIFF:      LOAD           0x002000 0x00002000 0x00002000 0x00038 0x00038 RW  0x1000
// DIFF-NOT:  LOAD

// DIFF: 01     .dynsym .gnu.hash .hash .dynstr
// DIFF: 02     .text .foo
// DIFF: 03     .dynamic

        bx lr
        .section .foo,"axy"
        bx lr
