// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux %s -o %t.o

// Creates a R_ARM_ABS32 relocation against foo and bar, bar has hidden
// visibility so we expect a R_ARM_RELATIVE
 .syntax unified
 .globl foo
foo:
 .globl bar
 .hidden bar
bar:

 .data
 .word foo
 .word bar

// RUN: ld.lld -shared -o %t.so %t.o
// RUN: llvm-readobj -symbols -dyn-relocations %t.so | FileCheck %s

// CHECK:      Dynamic Relocations {
// CHECK-NEXT:   0x1004 R_ARM_RELATIVE
// CHECK-NEXT:   0x1000 R_ARM_ABS32 foo 0x0
// CHECK-NEXT: }

// CHECK:      Symbols [
// CHECK:        Symbol {
// CHECK:          Name: bar
// CHECK-NEXT:     Value: 0x1000

// CHECK:        Symbol {
// CHECK:          Name: foo
// CHECK-NEXT:     Value: 0x1000
