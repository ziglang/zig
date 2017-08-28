// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %s -o %t.o -relax-relocations
// RUN: ld.lld -shared %t.o -o %t.so
// RUN: llvm-objdump -d %t.so | FileCheck %s

foo:
        movl bar@GOT(%ebx), %eax
        movl bar+8@GOT(%ebx), %eax

// CHECK: foo:
// CHECK-NEXT: movl    -4(%ebx), %eax
// CHECK-NEXT: movl    4(%ebx), %eax
