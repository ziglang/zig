// REQUIRES: arm
// RUN: llvm-mc -arm-add-build-attributes -filetype=obj -triple=thumbv7a-none-linux-gnueabi %s -o %t
// RUN: ld.lld %t -o %t2 2>&1
// The output file is large, most of it zeroes. We dissassemble only the
// parts we need to speed up the test and avoid a large output file
// RUN: llvm-objdump -d %t2 -start-address=524288 -stop-address=524316 -triple=thumbv7a-linux-gnueabihf | FileCheck -check-prefix=CHECK1 %s
// RUN: llvm-objdump -d %t2 -start-address=1048576 -stop-address=1048584 -triple=thumbv7a-linux-gnueabihf | FileCheck -check-prefix=CHECK2 %s
// RUN: llvm-objdump -d %t2 -start-address=1572864 -stop-address=1572872 -triple=thumbv7a-linux-gnueabihf | FileCheck -check-prefix=CHECK3 %s
// RUN: llvm-objdump -d %t2 -start-address=5242884 -stop-address=5242894 -triple=thumbv7a-linux-gnueabihf | FileCheck -check-prefix=CHECK4 %s
// RUN: llvm-objdump -d %t2 -start-address=5767168 -stop-address=5767174 -triple=thumbv7a-linux-gnueabihf | FileCheck -check-prefix=CHECK5 %s
// RUN: llvm-objdump -d %t2 -start-address=16777220 -stop-address=16777240 -triple=thumbv7a-linux-gnueabihf | FileCheck -check-prefix=CHECK6 %s
// RUN: llvm-objdump -d %t2 -start-address=17825792 -stop-address=17825798 -triple=thumbv7a-linux-gnueabihf | FileCheck -check-prefix=CHECK7 %s
// Test Range extension Thunks for the Thumb conditional branch instruction.
// This instruction only has a range of 1Mb whereas all the other Thumb wide
// Branch instructions have 16Mb range. We still place our pre-created Thunk
// Sections at 16Mb intervals as conditional branches to a target defined
// in a different section are rare.
 .syntax unified
// Define a function aligned on a half megabyte boundary
 .macro FUNCTION suff
 .section .text.\suff\(), "ax", %progbits
 .thumb
 .balign 0x80000
 .globl tfunc\suff\()
 .type  tfunc\suff\(), %function
tfunc\suff\():
 bx lr
 .endm

 .globl _start
_start:
 FUNCTION 00
// Long Range Thunk needed for 16Mb range branch, can reach pre-created Thunk
// Section
 bl tfunc33
// CHECK1: Disassembly of section .text:
// CHECK1-EMPTY:
// CHECK1-NEXT: tfunc00:
// CHECK1-NEXT:    80000:       70 47   bx      lr
// CHECK1-NEXT:    80002:       7f f3 ff d7     bl      #16252926
// CHECK1: __Thumbv7ABSLongThunk_tfunc05:
// CHECK1-NEXT:    80008:       7f f2 fa bf     b.w     #2621428 <tfunc05>
// CHECK1: __Thumbv7ABSLongThunk_tfunc00:
// CHECK1-NEXT:    8000c:       ff f7 f8 bf     b.w     #-16 <tfunc00>
 FUNCTION 01
// tfunc02 is within range of tfunc02
 beq.w tfunc02
// tfunc05 is out of range, and we can't reach the pre-created Thunk Section
// create a new one.
 bne.w tfunc05
// CHECK2:  tfunc01:
// CHECK2-NEXT:   100000:       70 47   bx      lr
// CHECK2-NEXT:   100002:       3f f0 fd a7     beq.w   #524282 <tfunc02>
// CHECK2-NEXT:   100006:       7f f4 ff a7     bne.w   #-524290 <__Thumbv7ABSLongThunk_tfunc05>
 FUNCTION 02
// We can reach the Thunk Section created for bne.w tfunc05
 bne.w tfunc05
 beq.w tfunc00
// CHECK3:   180000:       70 47   bx      lr
// CHECK3-NEXT:   180002:       40 f4 01 80     bne.w   #-1048574 <__Thumbv7ABSLongThunk_tfunc05>
// CHECK3-NEXT:   180006:       00 f4 01 80     beq.w   #-1048574 <__Thumbv7ABSLongThunk_tfunc00>
 FUNCTION 03
 FUNCTION 04
 FUNCTION 05
 FUNCTION 06
 FUNCTION 07
 FUNCTION 08
 FUNCTION 09
// CHECK4:  __Thumbv7ABSLongThunk_tfunc03:
// CHECK4-NEXT:   500004:       ff f4 fc bf     b.w     #-3145736 <tfunc03>
 FUNCTION 10
// We can't reach any Thunk Section, create a new one
 beq.w tfunc03
// CHECK5: tfunc10:
// CHECK5-NEXT:   580000:       70 47   bx      lr
// CHECK5-NEXT:   580002:       3f f4 ff a7     beq.w   #-524290 <__Thumbv7ABSLongThunk_tfunc03>
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
// CHECK6:  __Thumbv7ABSLongThunk_tfunc33:
// CHECK6-NEXT:  1000004:       ff f0 fc bf     b.w     #1048568 <tfunc33>
// CHECK6: __Thumbv7ABSLongThunk_tfunc00:
// CHECK6-NEXT:  1000008:       7f f4 fa 97     b.w     #-16252940 <tfunc00>
 FUNCTION 32
 FUNCTION 33
 // We should be able to reach an existing ThunkSection.
 b.w tfunc00
// CHECK7: tfunc33:
// CHECK7-NEXT:  1100000:       70 47   bx      lr
// CHECK7-NEXT:  1100002:       00 f7 01 b8     b.w     #-1048574 <__Thumbv7ABSLongThunk_tfunc00>
