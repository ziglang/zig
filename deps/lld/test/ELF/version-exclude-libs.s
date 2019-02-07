// REQUIRES: x86
// RUN: llvm-mc %p/Inputs/versiondef.s -o %t.o -filetype=obj -triple=x86_64-pc-linux
// RUN: rm -f %t.a
// RUN: llvm-ar -r %t.a %t.o
// RUN: llvm-mc %s -o %t2.o -filetype=obj -triple=x86_64-pc-linux
// RUN: ld.lld %t2.o %t.a --shared --exclude-libs ALL -o %t.so
// RUN: llvm-readobj -symbols %t.so | FileCheck %s
// RUN: llvm-readobj -dyn-symbols %t.so | FileCheck -check-prefix CHECK-DYN %s
// RUN: not ld.lld %t2.o %t.a --shared -o %t.so 2>&1 | FileCheck -check-prefix=CHECK-ERR %s

// Test that we do not give an error message for undefined versions when the
// symbol is not exported to the dynamic symbol table.

// CHECK:          Name: func
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size:
// CHECK-NEXT:     Binding: Local (0x0)

// CHECK-DYN-NOT: func

// CHECK-ERR: symbol func@@VER2 has undefined version VER2
// CHECK-ERR-NEXT: symbol func@VER has undefined version VER

 .text
 .globl _start
 .globl func
_start:
 ret

 .data
 .quad func
