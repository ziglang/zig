// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: ld.lld -pie %t.o -o %t
// RUN: llvm-readobj -V --dyn-syms %t | FileCheck %s

        .globl _start
_start:
        .type foo,@function
        .weak foo
        .long foo@gotpcrel

// Test that an entry for weak undefined symbols is NOT emitted in .dynsym as
// the PIE was not linked with any shared libraries. There are other tests which
// ensure that the weak undefined symbols do get emitted in .dynsym for PIEs
// linked against dynamic libraries.


// CHECK:      DynamicSymbols [
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name:
// CHECK-NEXT:     Value: 0x0
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local (0x0)
// CHECK-NEXT:     Type: None (0x0)
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: Undefined (0x0)
// CHECK-NEXT:   }
// CHECK-NEXT: ]
