// REQUIRES: x86

// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/shared.s -o %t1.o
// RUN: ld.lld -o %t.so -shared %t1.o

// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t2.o
// RUN: ld.lld -o %t1.exe %t2.o %t.so -image-base=0xcafe00000000
// RUN: llvm-objdump -s -j .got.plt %t1.exe | FileCheck %s

// CHECK:      Contents of section .got.plt:
// CHECK-NEXT: cafe00002000 00300000 feca0000 00000000 00000000
// CHECK-NEXT: cafe00002010 00000000 00000000 26100000 feca0000

// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t2.o
// RUN: ld.lld -o %t2.exe %t2.o %t.so -image-base=0xcafe00000000 -z retpolineplt
// RUN: llvm-objdump -s -j .got.plt %t2.exe | FileCheck -check-prefix=RETPOLINE %s

// RETPOLINE:      Contents of section .got.plt:
// RETPOLINE-NEXT: cafe00002000 00300000 feca0000 00000000 00000000
// RETPOLINE-NEXT: cafe00002010 00000000 00000000 51100000 feca0000

.global _start
_start:
  jmp bar@PLT
