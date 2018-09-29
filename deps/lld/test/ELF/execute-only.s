// REQUIRES: aarch64

// RUN: llvm-mc -filetype=obj -triple=aarch64-linux-none %s -o %t.o
// RUN: ld.lld -Ttext=0xcafe0000 %t.o -o %t.so -shared -execute-only
// RUN: llvm-readelf -l %t.so | FileCheck %s

// CHECK:      LOAD {{.*}} 0x00000000cafe0000 0x000004 0x000004   E 0x{{.*}}
// CHECK-NOT:  LOAD {{.*}} 0x00000000cafe0000 0x000004 0x000004 R E 0x{{.*}}

        br lr
