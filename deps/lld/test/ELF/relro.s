// REQUIRES: x86

// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/shared.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so

// RUN: ld.lld %t.o %t2.so -z now -z norelro -z relro -o %t
// RUN: llvm-readelf -l %t | FileCheck --check-prefix=CHECK --check-prefix=FULLRELRO %s

// RUN: ld.lld %t.o %t2.so -z norelro -z relro -o %t
// RUN: llvm-readelf -l %t | FileCheck --check-prefix=CHECK --check-prefix=PARTRELRO %s

// RUN: ld.lld %t.o %t2.so -z norelro -o %t
// RUN: llvm-readelf -l %t | FileCheck --check-prefix=NORELRO %s

// CHECK:      Program Headers:
// CHECK-NEXT: Type
// CHECK-NEXT: PHDR
// CHECK-NEXT: LOAD
// CHECK-NEXT: LOAD
// CHECK-NEXT: LOAD
// CHECK-NEXT: LOAD
// CHECK-NEXT: DYNAMIC
// CHECK-NEXT: GNU_RELRO
// CHECK: Section to Segment mapping:

// FULLRELRO:  03     .openbsd.randomdata .dynamic .got .got.plt {{$}}
// PARTRELRO:  03     .openbsd.randomdata .dynamic .got {{$}}


// NORELRO-NOT: GNU_RELRO

.global _start
_start:
  .long bar
  jmp *bar2@GOTPCREL(%rip)

.section .data,"aw"
.quad 0

.zero 4
.section .foo,"aw"
.section .bss,"",@nobits

.section .openbsd.randomdata, "aw"
.quad 0
