// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %s -o %t.o -relax-relocations
// RUN: ld.lld -shared %t.o -o %t.so
// RUN: llvm-readelf -S %t.so | FileCheck --check-prefix=SEC %s
// RUN: llvm-objdump -d %t.so | FileCheck %s

// SEC:      .got PROGBITS 00002050
// SEC-NEXT: .got.plt PROGBITS 00003000

// 0x2050 - 0x3000 = -4016
// CHECK: foo:
// CHECK-NEXT: movl    -4016(%ebx), %eax
// CHECK-NEXT: movl    -4008(%ebx), %eax

foo:
        movl bar@GOT(%ebx), %eax
        movl bar+8@GOT(%ebx), %eax
