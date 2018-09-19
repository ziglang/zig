// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t
// RUN: ld.lld %t -o %t2 2>&1
// The output file is large, most of it zeroes. We dissassemble only the
// parts we need to speed up the test and avoid a large output file
// RUN: llvm-objdump -d %t2 -start-address=1048578 -stop-address=1048586 -triple=thumbv7a-linux-gnueabihf  | FileCheck -check-prefix=CHECK1 %s
// RUN: llvm-objdump -d %t2 -start-address=16777224 -stop-address=16777254 -triple=thumbv7a-linux-gnueabihf  | FileCheck -check-prefix=CHECK2 %s
// RUN: llvm-objdump -d %t2 -start-address=17825812 -stop-address=17825826 -triple=thumbv7a-linux-gnueabihf  | FileCheck -check-prefix=CHECK3 %s
// In this test case a branch that is in range and does not need its range
// extended can be pushed out of range by another Thunk, necessitating another
// pass

 .macro FUNCTION suff
 .section .text.\suff\(), "ax", %progbits
 .thumb
 .balign 0x100000
 .globl tfunc\suff\()
 .type  tfunc\suff\(), %function
tfunc\suff\():
 bx lr
 .endm

 FUNCTION 00
 .globl _start
_start:
 bl target
 b.w arm_target
// arm_target is in range but needs an interworking thunk
// CHECK1: _start:
// CHECK1-NEXT:   100002:       00 f3 06 d0     bl      #15728652
// CHECK1-NEXT:   100006:       ff f2 ff 97     b.w     #15728638 <__Thumbv7ABSLongThunk_arm_target>
 nop
 nop
 nop
 .globl target2
 .type target2, %function
        nop

target2:
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

 .section .text.16, "ax", %progbits
 .arm
 .globl arm_target
 .type arm_target, %function
arm_target:
 bx lr
// CHECK2: __Thumbv7ABSLongThunk_arm_target:
// CHECK2-NEXT:  1000008:       40 f2 02 0c     movw    r12, #2
// CHECK2-NEXT:  100000c:       c0 f2 00 1c     movt    r12, #256
// CHECK2-NEXT:  1000010:       60 47   bx      r12
// CHECK2: __Thumbv7ABSLongThunk_target:
// CHECK2-NEXT:  1000012:       ff f0 ff bf     b.w     #1048574 <target>
// CHECK2: __Thumbv7ABSLongThunk_target2:
// CHECK2-NEXT:  1000016:       ff f4 fc 97     b.w     #-15728648 <target2>

 .section .text.17, "ax", %progbits
// Just enough space so that bl target is in range if no extension thunks are
// generated.

 .space 0x100000 - 6

 .section .text.18, "ax", %progbits
 .thumb
 .globl target
 .type target, %function
// target is at maximum ARM branch range away from caller.
target:
// Similar case in the backwards direction
 bl target2
 nop
 nop
 bx lr
// CHECK3: target:
// CHECK3-NEXT:  1100014:       ff f6 ff ff     bl      #-1048578
// CHECK3-NEXT:  1100018:       00 bf   nop
// CHECK3-NEXT:  110001a:       00 bf   nop
// CHECK3-NEXT:  110001c:       70 47   bx      lr
