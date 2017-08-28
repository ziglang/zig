// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -relax-relocations -triple=x86_64-pc-linux %s \
// RUN:   -o %t.o
// RUN: llvm-mc -filetype=obj -relax-relocations -triple=x86_64-pc-linux \
// RUN:   %p/Inputs/x86-64-relax-offset.s -o %t2.o
// RUN: ld.lld %t2.o %t.o -o %t.so -shared
// RUN: llvm-objdump -d %t.so | FileCheck %s

        mov foo@gotpcrel(%rip), %rax
        nop

// CHECK:      1004: {{.*}} leaq    -11(%rip), %rax
// CHECK-NEXT: 100b: {{.*}} nop
