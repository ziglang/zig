// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=thumbv7a-none-linux-gnueabi %s -o %t
// RUN: ld.lld %t --shared --icf=all -o %t.so
// The output file is large, most of it zeroes. We dissassemble only the
// parts we need to speed up the test and avoid a large output file
// RUN: llvm-objdump -d %t.so -start-address=0x2000000 -stop-address=0x2000018 -triple=thumbv7a-linux-gnueabihf | FileCheck -check-prefix=CHECK1 %s
// RUN: llvm-objdump -d %t.so -start-address=0x2800004 -stop-address=0x2800034 -triple=thumbv7a-linux-gnueabihf | FileCheck -check-prefix=CHECK2 %s
// RUN: llvm-objdump -d %t.so -start-address=0x4000000 -stop-address=0x4000010 -triple=thumbv7a-linux-gnueabihf | FileCheck -check-prefix=CHECK3 %s
// RUN: llvm-objdump -d %t.so -start-address=0x4000010 -stop-address=0x4000100 -triple=armv7a-linux-gnueabihf | FileCheck -check-prefix=CHECK4 %s
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
 .global far_nonpreemptible
 .hidden far_nonpreemptible
 .type far_nonpreemptible, %function
 .global far_nonpreemptible_alias
 .hidden far_nonpreemptible_alias
 .type far_nonpreemptible_alias, %function
sym1:
 bl elsewhere
 bl preemptible
 bx lr
preemptible:
 bl far_preemptible
 bl far_nonpreemptible
 bl far_nonpreemptible_alias
 bx lr
// CHECK1: Disassembly of section .text:
// CHECK1-NEXT: sym1:
// CHECK1-NEXT:  2000000:       00 f0 00 d8     bl      #8388608
// CHECK1-NEXT:  2000004:       00 f0 04 d8     bl      #8388616
// CHECK1-NEXT:  2000008:       70 47   bx      lr
// CHECK1: preemptible:
// CHECK1-NEXT:  200000a:       00 f0 07 d8     bl      #8388622
// CHECK1-NEXT:  200000e:       00 f0 0b d8     bl      #8388630
// CHECK1-NEXT:  2000012:       00 f0 09 d8     bl      #8388626
// CHECK1-NEXT:  2000016:       70 47   bx      lr

 .section .text.2, "ax", %progbits
 .balign 0x0800000
 bx lr
// CHECK2: __ThumbV7PILongThunk_elsewhere:
// CHECK2-NEXT:  2800004:       40 f2 20 0c     movw    r12, #32
// CHECK2-NEXT:  2800008:       c0 f2 80 1c     movt    r12, #384
// CHECK2-NEXT:  280000c:       fc 44   add     r12, pc
// CHECK2-NEXT:  280000e:       60 47   bx      r12
// CHECK2: __ThumbV7PILongThunk_preemptible:
// CHECK2-NEXT:  2800010:       40 f2 24 0c     movw    r12, #36
// CHECK2-NEXT:  2800014:       c0 f2 80 1c     movt    r12, #384
// CHECK2-NEXT:  2800018:       fc 44   add     r12, pc
// CHECK2-NEXT:  280001a:       60 47   bx      r12
// CHECK2: __ThumbV7PILongThunk_far_preemptible:
// CHECK2-NEXT:  280001c:       40 f2 28 0c     movw    r12, #40
// CHECK2-NEXT:  2800020:       c0 f2 80 1c     movt    r12, #384
// CHECK2-NEXT:  2800024:       fc 44   add     r12, pc
// CHECK2-NEXT:  2800026:       60 47   bx      r12
// CHECK2: __ThumbV7PILongThunk_far_nonpreemptible:
// CHECK2-NEXT:  2800028:       4f f6 cd 7c     movw    r12, #65485
// CHECK2-NEXT:  280002c:       c0 f2 7f 1c     movt    r12, #383
// CHECK2-NEXT:  2800030:       fc 44   add     r12, pc
// CHECK2-NEXT:  2800032:       60 47   bx      r12

 .section .text.3, "ax", %progbits
.balign 0x2000000
far_preemptible:
far_nonpreemptible:
 bl elsewhere

 .section .text.4, "ax", %progbits
.balign 0x2000000
far_nonpreemptible_alias:
 bl elsewhere

// CHECK3: far_preemptible:
// CHECK3:  4000000:       00 f0 16 e8     blx     #44

// CHECK4: Disassembly of section .plt:
// CHECK4-NEXT: $a:
// CHECK4-NEXT:  4000010:	04 e0 2d e5 	str	lr, [sp, #-4]!
// CHECK4-NEXT:  4000014:	00 e6 8f e2 	add	lr, pc, #0, #12
// CHECK4-NEXT:  4000018:	00 ea 8e e2 	add	lr, lr, #0, #20
// CHECK4-NEXT:  400001c:	ec ff be e5 	ldr	pc, [lr, #4076]!
// CHECK4: $d:
// CHECK4-NEXT:  4000020:	d4 d4 d4 d4 	.word	0xd4d4d4d4
// CHECK4-NEXT:  4000024:	d4 d4 d4 d4 	.word	0xd4d4d4d4
// CHECK4-NEXT:  4000028:	d4 d4 d4 d4 	.word	0xd4d4d4d4
// CHECK4-NEXT:  400002c:	d4 d4 d4 d4 	.word	0xd4d4d4d4
// CHECK4: $a:
// CHECK4-NEXT:  4000030:	00 c6 8f e2 	add	r12, pc, #0, #12
// CHECK4-NEXT:  4000034:	00 ca 8c e2 	add	r12, r12, #0, #20
// CHECK4-NEXT:  4000038:	d4 ff bc e5 	ldr	pc, [r12, #4052]!
// CHECK4: $d:
// CHECK4-NEXT:  400003c:	d4 d4 d4 d4 	.word	0xd4d4d4d4
// CHECK4: $a:
// CHECK4-NEXT:  4000040:	00 c6 8f e2 	add	r12, pc, #0, #12
// CHECK4-NEXT:  4000044:	00 ca 8c e2 	add	r12, r12, #0, #20
// CHECK4-NEXT:  4000048:	c8 ff bc e5 	ldr	pc, [r12, #4040]!
// CHECK4: $d:
// CHECK4-NEXT:  400004c:	d4 d4 d4 d4 	.word	0xd4d4d4d4
// CHECK4: $a:
// CHECK4-NEXT:  4000050:	00 c6 8f e2 	add	r12, pc, #0, #12
// CHECK4-NEXT:  4000054:	00 ca 8c e2 	add	r12, r12, #0, #20
// CHECK4-NEXT:  4000058:	bc ff bc e5 	ldr	pc, [r12, #4028]!
// CHECK4: $d:
// CHECK4-NEXT:  400005c:	d4 d4 d4 d4 	.word	0xd4d4d4d4
