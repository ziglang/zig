// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=thumbv7a-none-linux-gnueabi %s -o %t
// RUN: ld.lld %t -o %t2 2>&1
// RUN: llvm-objdump -d %t2 -start-address=69632 -stop-address=69646 -triple=thumbv7a-linux-gnueabihf | FileCheck -check-prefix=CHECK1 %s
// RUN: llvm-objdump -d %t2 -start-address=16846856 -stop-address=16846874 -triple=thumbv7a-linux-gnueabihf | FileCheck -check-prefix=CHECK2 %s
 .syntax unified
 .global _start, foo
 .type _start, %function
 .section .text.start,"ax",%progbits
_start:
 bl _start
 .section .text.dummy1,"ax",%progbits
 .space 0xfffffe
 .section .text.foo,"ax",%progbits
  .type foo, %function
foo:
 bl _start

// CHECK1: Disassembly of section .text:
// CHECK1-NEXT: _start:
// CHECK1-NEXT:    11000:       ff f7 fe ff     bl      #-4
// CHECK1: __Thumbv7ABSLongThunk__start:
// CHECK1-NEXT:    11004:       ff f7 fc bf     b.w     #-8 <_start>

// CHECK2: __Thumbv7ABSLongThunk__start:
// CHECK2:       1011008:       41 f2 01 0c     movw    r12, #4097
// CHECK2-NEXT:  101100c:       c0 f2 01 0c     movt    r12, #1
// CHECK2-NEXT:  1011010:       60 47   bx      r12
// CHECK2: foo:
// CHECK2-NEXT:  1011012:       ff f7 f9 ff     bl      #-14
