// REQUIRES: arm
// RUN: llvm-mc %s -triple=armv7-unknown-linux-gnueabi -filetype=obj -o %t.o
// RUN: ld.lld -r %t.o -o %t
// RUN: llvm-readobj -s %t | FileCheck %s
// Check that when doing a relocatable link we don't add a terminating entry
// to the .ARM.exidx section
 .syntax unified
 .text
_start:
 .fnstart
 .cantunwind
 bx lr
 .fnend

// Expect 1 table entry of size 8
// CHECK: Name: .ARM.exidx
// CHECK: Size: 8
