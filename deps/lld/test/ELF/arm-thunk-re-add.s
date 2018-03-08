// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=thumbv7a-none-linux-gnueabi %s -o %t
// RUN: ld.lld %t --shared -o %t.so
// The output file is large, most of it zeroes. We dissassemble only the
// parts we need to speed up the test and avoid a large output file
// RUN: llvm-objdump -d %t.so -start-address=16777220 -stop-address=16777244 -triple=thumbv7a-linux-gnueabihf | FileCheck -check-prefix=CHECK1 %s
// RUN: llvm-objdump -d %t.so -start-address=17825800 -stop-address=17825826 -triple=thumbv7a-linux-gnueabihf | FileCheck -check-prefix=CHECK2 %s
// RUN: llvm-objdump -d %t.so -start-address=17825824 -stop-address=17825892 -triple=armv7a-linux-gnueabihf | FileCheck -check-prefix=CHECK3 %s

// A branch to a Thunk that we create on pass N, can drift out of range if
// other Thunks are added in between. In this case we must create a new Thunk
// for the branch that is in range. We also need to make sure that if the
// destination of the Thunk is in the PLT the new Thunk also targets the PLT
 .syntax unified
 .thumb

 .macro FUNCTION suff
 .section .text.\suff\(), "ax", %progbits
 .thumb
 .balign 0x80000
 .globl tfunc\suff\()
 .type  tfunc\suff\(), %function
tfunc\suff\():
 bx lr
 .endm

 .globl imported
 .type imported, %function
 .globl imported2
 .type imported2, %function
 .globl imported3
 .type imported3, %function
.globl imported4
 .type imported4, %function
 FUNCTION 00
 FUNCTION 01
 FUNCTION 02
 FUNCTION 03
 FUNCTION 04
 FUNCTION 05
 FUNCTION 06
 FUNCTION 07
 FUNCTION 08
 FUNCTION 09
 FUNCTION 10
 FUNCTION 11
 FUNCTION 12
 FUNCTION 13
 FUNCTION 14
 FUNCTION 15
 FUNCTION 16
 FUNCTION 17
 FUNCTION 18
 FUNCTION 19
 FUNCTION 20
 FUNCTION 21
 FUNCTION 22
 FUNCTION 23
 FUNCTION 24
 FUNCTION 25
 FUNCTION 26
 FUNCTION 27
 FUNCTION 28
 FUNCTION 29
 FUNCTION 30
 FUNCTION 31
// Precreated Thunk Pool goes here
// CHECK1: __ThumbV7PILongThunk_imported:
// CHECK1-NEXT:  1000004:       40 f2 30 0c     movw    r12, #48
// CHECK1-NEXT:  1000008:       c0 f2 10 0c     movt    r12, #16
// CHECK1-NEXT:  100000c:       fc 44   add     r12, pc
// CHECK1-NEXT:  100000e:       60 47   bx      r12
// CHECK1: __ThumbV7PILongThunk_imported2:
// CHECK1-NEXT:  1000010:       40 f2 34 0c     movw    r12, #52
// CHECK1-NEXT:  1000014:       c0 f2 10 0c     movt    r12, #16
// CHECK1-NEXT:  1000018:       fc 44   add     r12, pc
// CHECK1-NEXT:  100001a:       60 47   bx      r12

 .section .text.32, "ax", %progbits
 .space 0x80000
 .section .text.33, "ax", %progbits
 .space 0x80000 - 0x14
 .section .text.34, "ax", %progbits
 // Need a Thunk to the PLT entry, can use precreated ThunkSection
 .globl callers
 .type callers, %function
callers:
 b.w imported
 beq.w imported
 b.w imported2
// CHECK2: __ThumbV7PILongThunk_imported:
// CHECK2-NEXT:  1100008:       40 f2 2c 0c     movw    r12, #44
// CHECK2-NEXT:  110000c:       c0 f2 00 0c     movt    r12, #0
// CHECK2-NEXT:  1100010:       fc 44   add     r12, pc
// CHECK2-NEXT:  1100012:       60 47   bx      r12
// CHECK2: callers:
// CHECK2-NEXT:  1100014:       ff f6 f6 bf     b.w     #-1048596 <__ThumbV7PILongThunk_imported>
// CHECK2-NEXT:  1100018:       3f f4 f6 af     beq.w   #-20 <__ThumbV7PILongThunk_imported>
// CHECK2-NEXT:  110001c:       ff f6 f8 bf     b.w     #-1048592 <__ThumbV7PILongThunk_imported2>

// CHECK3: Disassembly of section .plt:
// CHECK3-NEXT: $a:
// CHECK3-NEXT:  1100020:       04 e0 2d e5     str     lr, [sp, #-4]!
// CHECK3-NEXT:  1100024:       00 e6 8f e2     add     lr, pc, #0, #12
// CHECK3-NEXT:  1100028:       00 ea 8e e2     add     lr, lr, #0, #20
// CHECK3-NEXT:  110002c:       dc ff be e5     ldr     pc, [lr, #4060]!
// CHECK3: $d:
// CHECK3-NEXT:  1100030:       d4 d4 d4 d4     .word   0xd4d4d4d4
// CHECK3-NEXT:  1100034:       d4 d4 d4 d4     .word   0xd4d4d4d4
// CHECK3-NEXT:  1100038:       d4 d4 d4 d4     .word   0xd4d4d4d4
// CHECK3-NEXT:  110003c:       d4 d4 d4 d4     .word   0xd4d4d4d4
// CHECK3: $a:
// CHECK3-NEXT:  1100040:       00 c6 8f e2     add     r12, pc, #0, #12
// CHECK3-NEXT:  1100044:       00 ca 8c e2     add     r12, r12, #0, #20
// CHECK3-NEXT:  1100048:       c4 ff bc e5     ldr     pc, [r12, #4036]!
// CHECK3: $d:
// CHECK3-NEXT:  110004c:       d4 d4 d4 d4     .word   0xd4d4d4d4
// CHECK3: $a:
// CHECK3-NEXT:  1100050:       00 c6 8f e2     add     r12, pc, #0, #12
// CHECK3-NEXT:  1100054:       00 ca 8c e2     add     r12, r12, #0, #20
// CHECK3-NEXT:  1100058:       b8 ff bc e5     ldr     pc, [r12, #4024]!
// CHECK3: $d:
// CHECK3-NEXT:  110005c:       d4 d4 d4 d4     .word   0xd4d4d4d4
