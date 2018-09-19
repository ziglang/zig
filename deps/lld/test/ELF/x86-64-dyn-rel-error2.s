// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/shared.s -o %t2.o
// RUN: ld.lld %t2.o -shared -o %t2.so
// RUN: not ld.lld -shared %t.o %t2.so -o /dev/null 2>&1 | FileCheck %s

// CHECK: relocation R_X86_64_PC32 cannot be used against symbol zed; recompile with -fPIC
// CHECK: >>> defined in {{.*}}.so
// CHECK: >>> referenced by {{.*}}.o:(.data+0x0)

        .global _start
_start:
        .data
        .long zed - .
