// REQUIRES: arm
// RUN: llvm-mc -arm-add-build-attributes -filetype=obj -triple=thumbv7a-none-linux-gnueabi %s -o %t
// RUN: ld.lld %t -o %t2 2>&1
// RUN: llvm-objdump -d -triple=thumbv7a-none-linux-gnueabi -start-address=69632 -stop-address=69636 %t2 | FileCheck -check-prefix=CHECK1 %s
// RUN: llvm-objdump -d -triple=thumbv7a-none-linux-gnueabi -start-address=73732 -stop-address=73742 %t2 | FileCheck -check-prefix=CHECK2 %s
// RUN: llvm-objdump -d -triple=thumbv7a-none-linux-gnueabi -start-address=16850936 -stop-address=16850940 %t2 | FileCheck -check-prefix=CHECK3 %s
// RUN: llvm-objdump -d -triple=thumbv7a-none-linux-gnueabi -start-address=33628152 -stop-address=33628156 %t2 | FileCheck -check-prefix=CHECK4 %s
// RUN: llvm-objdump -d -triple=thumbv7a-none-linux-gnueabi -start-address=50405356 -stop-address=50405376 %t2 | FileCheck -check-prefix=CHECK5 %s
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
// CHECK1-NEXT:_start:
// CHECK1-NEXT:   11000:       70 47   bx      lr
// CHECK1-EMPTY:
// CHECK-NEXT:$d.1:
// CHECK-NEXT:  11002:       00 00           .short  0x0000


// CHECK2: __Thumbv7ABSLongThunk__start:
// CHECK2-NEXT:    12004:       fe f7 fc bf     b.w     #-4104 <_start>

// Gigantic section where we need a ThunkSection either side of it
 .section .text.large1, "ax", %progbits
 .balign 4
 .space (16 * 1024 * 1024) - 16
 bl _start
 .space (16 * 1024 * 1024) - 4
 bl _start
 .space (16 * 1024 * 1024) - 16
// CHECK3: 1011ff8:     00 f4 04 d0     bl      #-16777208
// CHECK4: 2011ff8:     ff f3 f8 d7     bl      #16777200

// CHECK5: __Thumbv7ABSLongThunk__start:
// CHECK5-NEXT:  3011fec:       41 f2 01 0c     movw    r12, #4097
// CHECK5-NEXT:  3011ff0:       c0 f2 01 0c     movt    r12, #1
// CHECK5-NEXT:  3011ff4:       60 47   bx      r12
