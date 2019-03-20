// REQUIRES: arm
// RUN: llvm-mc -arm-add-build-attributes -filetype=obj -triple=armv6-none-linux-gnueabi %s -o %t
// RUN: ld.lld %t -o %t2 2>&1
// RUN: llvm-objdump -d -triple=armv6-none-linux-gnueabi -start-address=69632 -stop-address=69640 %t2 | FileCheck -check-prefix=CHECK-ARM1 %s
// RUN: llvm-objdump -d -triple=thumbv6-none-linux-gnueabi %t2 -start-address=69640 -stop-address=69644 | FileCheck -check-prefix=CHECK-THUMB1 %s
// RUN: llvm-objdump -d -triple=armv6-none-linux-gnueabi -start-address=2166796 -stop-address=2166804 %t2 | FileCheck -check-prefix=CHECK-ARM2 %s
// RUN: llvm-objdump -d -triple=thumbv6-none-linux-gnueabi %t2 -start-address=6365184 -stop-address=6365186 | FileCheck -check-prefix=CHECK-THUMB2 %s

// On Arm v6 the range of a Thumb BL instruction is only 4 megabytes as the
// extended range encoding is not supported. The following example has a Thumb
// BL that is out of range on ARM v6 and requires a range extension thunk.
// As v6 does not support MOVT or MOVW instructions the Thunk must not
// use these instructions either.


// ARM v6 supports blx so we shouldn't see the blx not supported warning.
// CHECK-NOT: warning: lld uses blx instruction, no object with architecture supporting feature detected.
 .text
 .syntax unified
 .cpu    arm1176jzf-s
 .globl _start
 .type   _start,%function
 .balign 0x1000
_start:
  bl thumbfunc
  bx lr

// CHECK-ARM1: Disassembly of section .text:
// CHECK-ARM1-NEXT: _start:
// CHECK-ARM1-NEXT:    11000:   00 00 00 fa     blx     #0 <thumbfunc>
// CHECK-ARM1-NEXT:    11004:   1e ff 2f e1     bx      lr
 .thumb
 .section .text.2, "ax", %progbits
 .globl thumbfunc
 .type thumbfunc,%function
thumbfunc:
 bl farthumbfunc

// CHECK-THUMB1: thumbfunc:
// CHECK-THUMB1-NEXT:    11008:	00 f2 00 e8 	blx	#2097152
// 6 Megabytes, enough to make farthumbfunc out of range of caller
// on a v6 Arm, but not on a v7 Arm.

 .section .text.3, "ax", %progbits
 .space 0x200000
// CHECK-ARM2: __ARMv5ABSLongThunk_farthumbfunc:
// CHECK-ARM2-NEXT:   21100c:   04 f0 1f e5     ldr     pc, [pc, #-4]
// CHECK-ARM2: $d:
// CHECK-ARM2-NEXT:   211010:   01 20 61 00     .word   0x00612001
 .section .text.4, "ax", %progbits
 .space 0x200000

 .section .text.5, "ax", %progbits
 .space 0x200000

 .thumb
 .section .text.6, "ax", %progbits
 .balign 0x1000
 .globl farthumbfunc
 .type farthumbfunc,%function
farthumbfunc:
 bx lr
// CHECK-THUMB2: farthumbfunc:
// CHECK-THUMB2-NEXT:   612000:        70 47   bx      lr
