// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: ld.lld %t --static -o %t2 2>&1
// RUN: llvm-readobj --symbols %t2 | FileCheck %s
// REQUIRES: arm

// Check that on ARM we don't get a multiply defined symbol for __tls_get_addr
// and undefined symbols for references to __exidx_start and __exidx_end
 .syntax unified
.section .text
 .global __tls_get_addr
__tls_get_addr:
 bx lr

 .global _start
 .global __exidx_start
 .global __exidx_end
_start:
 .fnstart
 bx lr
 .word __exidx_start
 .word __exidx_end
 .cantunwind
 .fnend

// CHECK:          Name: __exidx_end
// CHECK-NEXT:     Value: 0x100E4
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other [
// CHECK-NEXT:       STV_HIDDEN
// CHECK-NEXT:     ]
// CHECK-NEXT:     Section: .ARM.exidx
// CHECK:          Name: __exidx_start
// CHECK-NEXT:     Value: 0x100D4
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other [
// CHECK-NEXT:       STV_HIDDEN
// CHECK-NEXT:     ]
// CHECK-NEXT:   Section: .ARM.exidx
// CHECK:          Symbol {
// CHECK-NEXT:     Name: __tls_get_addr
