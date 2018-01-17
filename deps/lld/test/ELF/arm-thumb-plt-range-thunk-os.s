// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=thumbv7a-none-linux-gnueabi %s -o %t
// RUN: ld.lld %t --shared -o %t.so
// The output file is large, most of it zeroes. We dissassemble only the
// parts we need to speed up the test and avoid a large output file
// RUN: llvm-objdump -d %t.so -start-address=8388608 -stop-address=8388624 -triple=thumbv7a-linux-gnueabihf | FileCheck -check-prefix=CHECK1 %s
// RUN: llvm-objdump -d %t.so -start-address=16777216 -stop-address=16777256 -triple=thumbv7a-linux-gnueabihf | FileCheck -check-prefix=CHECK2 %s
// RUN: llvm-objdump -d %t.so -start-address=25165824 -stop-address=25165828 -triple=thumbv7a-linux-gnueabihf | FileCheck -check-prefix=CHECK3 %s
// RUN: llvm-objdump -d %t.so -start-address=25165828 -stop-address=25165924 -triple=armv7a-linux-gnueabihf | FileCheck -check-prefix=CHECK4 %s
 .syntax unified
 .thumb

// Make sure that we generate a range extension thunk to a PLT entry
 .section ".text.1", "ax", %progbits
 .global sym1
 .global elsewhere
 .type elsewhere, %function
 .global preemptible
 .type preemptible, %function
 .global far_preemptible
 .type far_preemptible, %function
sym1:
 bl elsewhere
 bl preemptible
 bx lr
preemptible:
 bl far_preemptible
 bx lr
// CHECK1: Disassembly of section .text:
// CHECK1-NEXT: sym1:
// CHECK1-NEXT:   800000:       00 f0 00 d8     bl      #8388608
// CHECK1-NEXT:   800004:       00 f0 04 d8     bl      #8388616
// CHECK1-NEXT:   800008:       70 47   bx      lr
// CHECK1: preemptible:
// CHECK1-NEXT:   80000a:       00 f0 07 d8     bl      #8388622
// CHECK1-NEXT:   80000e:       70 47   bx      lr

 .section .text.2, "ax", %progbits
 .balign 0x0800000
 bx lr
// CHECK2: __ThumbV7PILongThunk_elsewhere:
// CHECK2-NEXT:  1000004:       40 f2 20 0c     movw    r12, #32
// CHECK2-NEXT:  1000008:       c0 f2 80 0c     movt    r12, #128
// CHECK2-NEXT:  100000c:       fc 44   add     r12, pc
// CHECK2-NEXT:  100000e:       60 47   bx      r12
// CHECK2: __ThumbV7PILongThunk_preemptible:
// CHECK2-NEXT:  1000010:       40 f2 24 0c     movw    r12, #36
// CHECK2-NEXT:  1000014:       c0 f2 80 0c     movt    r12, #128
// CHECK2-NEXT:  1000018:       fc 44   add     r12, pc
// CHECK2-NEXT:  100001a:       60 47   bx      r12
// CHECK2: __ThumbV7PILongThunk_far_preemptible:
// CHECK2-NEXT:  100001c:       40 f2 28 0c     movw    r12, #40
// CHECK2-NEXT:  1000020:       c0 f2 80 0c     movt    r12, #128
// CHECK2-NEXT:  1000024:       fc 44   add     r12, pc
// CHECK2-NEXT:  1000026:       60 47   bx      r12

 .section .text.3, "ax", %progbits
.balign 0x0800000
far_preemptible:
 bl elsewhere
// CHECK3: far_preemptible:
// CHECK3:  1800000:       00 f0 16 e8     blx     #44

// CHECK4: Disassembly of section .plt:
// CHECK4-NEXT: $a:
// CHECK4-NEXT:  1800010:	04 e0 2d e5 	str	lr, [sp, #-4]!
// CHECK4-NEXT:  1800014:	00 e6 8f e2 	add	lr, pc, #0, #12
// CHECK4-NEXT:  1800018:	00 ea 8e e2 	add	lr, lr, #0, #20
// CHECK4-NEXT:  180001c:	ec ff be e5 	ldr	pc, [lr, #4076]!
// CHECK4: $d:
// CHECK4-NEXT:  1800020:	d4 d4 d4 d4 	.word	0xd4d4d4d4
// CHECK4-NEXT:  1800024:	d4 d4 d4 d4 	.word	0xd4d4d4d4
// CHECK4-NEXT:  1800028:	d4 d4 d4 d4 	.word	0xd4d4d4d4
// CHECK4-NEXT:  180002c:	d4 d4 d4 d4 	.word	0xd4d4d4d4
// CHECK4: $a:
// CHECK4-NEXT:  1800030:	00 c6 8f e2 	add	r12, pc, #0, #12
// CHECK4-NEXT:  1800034:	00 ca 8c e2 	add	r12, r12, #0, #20
// CHECK4-NEXT:  1800038:	d4 ff bc e5 	ldr	pc, [r12, #4052]!
// CHECK4: $d:
// CHECK4-NEXT:  180003c:	d4 d4 d4 d4 	.word	0xd4d4d4d4
// CHECK4: $a:
// CHECK4-NEXT:  1800040:	00 c6 8f e2 	add	r12, pc, #0, #12
// CHECK4-NEXT:  1800044:	00 ca 8c e2 	add	r12, r12, #0, #20
// CHECK4-NEXT:  1800048:	c8 ff bc e5 	ldr	pc, [r12, #4040]!
// CHECK4: $d:
// CHECK4-NEXT:  180004c:	d4 d4 d4 d4 	.word	0xd4d4d4d4
// CHECK4: $a:
// CHECK4-NEXT:  1800050:	00 c6 8f e2 	add	r12, pc, #0, #12
// CHECK4-NEXT:  1800054:	00 ca 8c e2 	add	r12, r12, #0, #20
// CHECK4-NEXT:  1800058:	bc ff bc e5 	ldr	pc, [r12, #4028]!
// CHECK4: $d:
// CHECK4-NEXT:  180005c:	d4 d4 d4 d4 	.word	0xd4d4d4d4
