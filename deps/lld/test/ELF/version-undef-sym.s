// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: llvm-readobj --dyn-symbols %p/Inputs/version-undef-sym.so | FileCheck %s


// Inputs/version-undef-sym.so consists of the assembly file
//
//         .global bar
// bar:
//        .weak abc1
//        .weak abc2
//        .weak abc3
//        .weak abc4
//        .weak abc5
//
// linked into a shared library with the version script
//
// VER_1 {
// global:
//   bar;
// };
//
// Assuming we can reproduce the desired property (a few undefined symbols
// before bar) we should create it with lld itself once it supports that.


// Show that the input .so has undefined symbols before bar. That is what would
// get our version parsing out of sync.

// CHECK: Section: Undefined
// CHECK: Section: Undefined
// CHECK: Section: Undefined
// CHECK: Section: Undefined
// CHECK: Section: Undefined
// CHECK: Name: bar

// But now we can successfully find bar.
// RUN: ld.lld %t.o %p/Inputs/version-undef-sym.so -o %t.exe

        .global _start
_start:
        call bar@plt
