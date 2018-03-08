// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=thumbv7a-none-linux-gnueabi %s -o %t
// RUN: echo "SECTIONS { \
// RUN:       .text 0x100000 : { *(.text) } \
// RUN:       .textl : { *(.text_l0*) *(.text_l1*) *(.text_l2*) *(.text_l3*) } \
// RUN:       .texth : { *(.text_h0*) *(.text_h1*) *(.text_h2*) *(.text_h3*) } \
// RUN:       }" > %t.script
// RUN: ld.lld --script %t.script %t -o %t2 2>&1
// The output file is large, most of it zeroes. We dissassemble only the
// parts we need to speed up the test and avoid a large output file
// RUN: llvm-objdump -d %t2 -start-address=1048576 -stop-address=1048594 -triple=thumbv7a-linux-gnueabihf | FileCheck --check-prefix=CHECK1 %s
// RUN: llvm-objdump -d %t2 -start-address=2097152 -stop-address=2097160 -triple=thumbv7a-linux-gnueabihf | FileCheck --check-prefix=CHECK2 %s
// RUN: llvm-objdump -d %t2 -start-address=11534340 -stop-address=11534350 -triple=thumbv7a-linux-gnueabihf | FileCheck --check-prefix=CHECK3 %s
// RUN: llvm-objdump -d %t2 -start-address=34603008 -stop-address=34603034 -triple=thumbv7a-linux-gnueabihf | FileCheck --check-prefix=CHECK4 %s
// RUN: llvm-objdump -d %t2 -start-address=35651584 -stop-address=35651598 -triple=thumbv7a-linux-gnueabihf | FileCheck --check-prefix=CHECK5 %s
// RUN: llvm-objdump -d %t2 -start-address=68157440 -stop-address=68157472 -triple=thumbv7a-linux-gnueabihf | FileCheck --check-prefix=CHECK6 %s

// Test the range extensions in a linker script where there are several
// OutputSections requiring range extension Thunks. We should be able to reuse
// Thunks between OutputSections but our placement of new Thunks is done on a
// per OutputSection basis
 .syntax unified

// Define a function that we can match with .text_l* aligned on a megabyte      // boundary
 .macro FUNCTIONL suff
 .section .text_l\suff\(), "ax", %progbits
 .thumb
 .balign 0x100000
 .globl tfuncl\suff\()
 .type  tfuncl\suff\(), %function
tfuncl\suff\():
 bx lr
 .endm

// Define a function that we can match with .text_h* aligned on a megabyte
// boundary
 .macro FUNCTIONH suff
 .section .text_h\suff\(), "ax", %progbits
 .thumb
 .balign 0x100000
 .globl tfunch\suff\()
 .type  tfunch\suff\(), %function
tfunch\suff\():
 bx lr
 .endm

 .section .text, "ax", %progbits
 .thumb
 .globl _start
_start:
 bl tfuncl00
 // Expect a range extension thunk in .text OutputSection
 bl tfunch31
// CHECK1: Disassembly of section .text:
// CHECK1-NEXT: _start:
// CHECK1-NEXT:   100000:       ff f0 fe ff     bl      #1048572
// CHECK1-NEXT:   100004:       00 f0 00 f8     bl      #0
// CHECK1: __Thumbv7ABSLongThunk_tfunch31:
// CHECK1-NEXT:   100008:       40 f2 01 0c     movw    r12, #1
// CHECK1-NEXT:   10000c:       c0 f2 10 4c     movt    r12, #1040
// CHECK1-NEXT:   100010:       60 47   bx      r12
 FUNCTIONL 00
 // Create a range extension thunk in .textl
 bl tfuncl24
 // We can reuse existing thunk in .text
 bl tfunch31
// CHECK2: Disassembly of section .textl:
// CHECK2-NEXT: tfuncl00:
// CHECK2-NEXT:   200000:	70 47 	bx	lr
// CHECK2-NEXT:   200002:	ff f0 ff df 	bl	#9437182
// CHECK2-NEXT:   200006:	ff f6 ff ff 	bl	#-1048578
 FUNCTIONL 01
 FUNCTIONL 02
 FUNCTIONL 03
 FUNCTIONL 04
 FUNCTIONL 05
 FUNCTIONL 06
 FUNCTIONL 07
 FUNCTIONL 08
 FUNCTIONL 09
// CHECK3: __Thumbv7ABSLongThunk_tfuncl24:
// CHECK3-NEXT:   b00004:	40 f2 01 0c 	movw	r12, #1
// CHECK3-NEXT:   b00008:	c0 f2 a0 1c 	movt	r12, #416
// CHECK3-NEXT:   b0000c:	60 47 	bx	r12
 FUNCTIONL 10
 FUNCTIONL 11
 FUNCTIONL 12
 FUNCTIONL 13
 FUNCTIONL 14
 FUNCTIONL 15
 FUNCTIONL 16
 FUNCTIONL 17
 FUNCTIONL 18
 FUNCTIONL 19
 FUNCTIONL 20
 FUNCTIONL 21
 FUNCTIONL 22
 FUNCTIONL 23
 FUNCTIONL 24
 FUNCTIONL 25
 FUNCTIONL 26
 FUNCTIONL 27
 FUNCTIONL 28
 FUNCTIONL 29
 FUNCTIONL 30
 FUNCTIONL 31
 // Create range extension thunks in .textl
 bl tfuncl00
 bl tfuncl24
 // Shouldn't need a thunk
 bl tfunch00
// CHECK4:  2100002:    00 f0 05 f8     bl      #10
// CHECK4-NEXT:  2100006:       ff f4 fb f7     bl      #-7340042
// CHECK4-NEXT:  210000a:       ff f0 f9 ff     bl      #1048562
// CHECK4: __Thumbv7ABSLongThunk_tfuncl00:
// CHECK4-NEXT:  2100010:       40 f2 01 0c     movw    r12, #1
// CHECK4-NEXT:  2100014:       c0 f2 20 0c     movt    r12, #32
// CHECK4-NEXT:  2100018:       60 47   bx      r12
 FUNCTIONH 00
 // Can reuse existing thunks in .textl
 bl tfuncl00
 bl tfuncl24
 // Shouldn't need a thunk
        bl tfuncl31
// CHECK5:  Disassembly of section .texth:
// CHECK5-NEXT: tfunch00:
// CHECK5-NEXT:  2200000:       70 47   bx      lr
// CHECK5-NEXT:  2200002:       00 f7 05 f8     bl      #-1048566
// CHECK5-NEXT:  2200006:       ff f7 fb df     bl      #-8388618
// CHECK5-NEXT:  220000a:       ff f6 f9 ff     bl      #-1048590
 FUNCTIONH 01
 FUNCTIONH 02
 FUNCTIONH 03
 FUNCTIONH 04
 FUNCTIONH 05
 FUNCTIONH 06
 FUNCTIONH 07
 FUNCTIONH 08
 FUNCTIONH 09
 FUNCTIONH 10
 FUNCTIONH 11
 FUNCTIONH 12
 FUNCTIONH 13
 FUNCTIONH 14
 FUNCTIONH 15
 FUNCTIONH 16
 FUNCTIONH 17
 FUNCTIONH 18
 FUNCTIONH 19
 FUNCTIONH 20
 FUNCTIONH 21
 FUNCTIONH 22
 FUNCTIONH 23
 FUNCTIONH 24
 FUNCTIONH 25
 FUNCTIONH 26
 FUNCTIONH 27
 FUNCTIONH 28
 FUNCTIONH 29
 FUNCTIONH 30
 FUNCTIONH 31
// expect Thunks in .texth
 bl tfuncl00
 bl tfunch00
// CHECK6: tfunch31:
// CHECK6-NEXT:  4100000:       70 47   bx      lr
// CHECK6-NEXT:  4100002:       00 f0 03 f8     bl      #6
// CHECK6-NEXT:  4100006:       00 f0 06 f8     bl      #12
// CHECK6: __Thumbv7ABSLongThunk_tfuncl00:
// CHECK6-NEXT:  410000c:       40 f2 01 0c     movw    r12, #1
// CHECK6-NEXT:  4100010:       c0 f2 20 0c     movt    r12, #32
// CHECK6-NEXT:  4100014:       60 47   bx      r12
// CHECK6: __Thumbv7ABSLongThunk_tfunch00:
// CHECK6-NEXT:  4100016:       40 f2 01 0c     movw    r12, #1
// CHECK6-NEXT:  410001a:       c0 f2 20 2c     movt    r12, #544
// CHECK6-NEXT:  410001e:       60 47   bx      r12
