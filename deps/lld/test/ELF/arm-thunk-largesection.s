// RUN: llvm-mc -filetype=obj -triple=thumbv7a-none-linux-gnueabi %s -o %t
// RUN: ld.lld %t -o %t2 2>&1
// RUN: llvm-objdump -d -triple=thumbv7a-none-linux-gnueabi -start-address=69632 -stop-address=69636 %t2 | FileCheck -check-prefix=CHECK1 %s
// RUN: llvm-objdump -d -triple=thumbv7a-none-linux-gnueabi -start-address=73732 -stop-address=73742 %t2 | FileCheck -check-prefix=CHECK2 %s
// RUN: llvm-objdump -d -triple=thumbv7a-none-linux-gnueabi -start-address=16850944 -stop-address=16850948 %t2 | FileCheck -check-prefix=CHECK3 %s
// RUN: llvm-objdump -d -triple=thumbv7a-none-linux-gnueabi -start-address=33628160 -stop-address=33628164 %t2 | FileCheck -check-prefix=CHECK4 %s
// RUN: llvm-objdump -d -triple=thumbv7a-none-linux-gnueabi -start-address=50405364 -stop-address=50405376 %t2 | FileCheck -check-prefix=CHECK5 %s
// REQUIRES: arm
 .syntax unified
 .balign 0x1000
 .thumb
 .text
 .globl _start
 .type _start, %function
_start:
 bx lr
 .space 0x1000
// CHECK1: Disassembly of section .text:
// CHECK1-NEXT: _start:
// CHECK1-NEXT:    11000:       70 47   bx      lr
// CHECK1-NEXT:    11002:       00 00   movs    r0, r0

// CHECK2: __Thumbv7ABSLongThunk__start:
// CHECK2-NEXT:    12004:       41 f2 01 0c     movw    r12, #4097
// CHECK2-NEXT:    12008:       c0 f2 01 0c     movt    r12, #1
// CHECK2-NEXT:    1200c:       60 47   bx      r12

// Gigantic section where we need a ThunkSection either side of it
 .section .text.large1, "ax", %progbits
 .balign 4
 .space (16 * 1024 * 1024) - 16
 bl _start
 .space (16 * 1024 * 1024) - 4
 bl _start
 .space (16 * 1024 * 1024) - 16
// CHECK3: 1012000:     00 f4 00 d0     bl      #-16777216
// CHECK4: 2012000:     ff f3 f8 d7     bl      #16777200

// CHECK5: __Thumbv7ABSLongThunk__start:
// CHECK5-NEXT:  3011ff4:       41 f2 01 0c     movw    r12, #4097
// CHECK5-NEXT:  3011ff8:       c0 f2 01 0c     movt    r12, #1
// CHECK5-NEXT:  3011ffc:       60 47   bx      r12
