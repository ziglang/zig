// REQUIRES: arm
// RUN: llvm-mc -arm-add-build-attributes -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t.o
// RUN: echo "SECTIONS { \
// RUN:           .text_armfunc 0x1000 : { *(.text_armfunc) } \
// RUN:           .text_thumbfunc 0x11010 : { *(.text_thumbfunc) } \
// RUN:       }" > %tarm_to_thumb.script
// RUN: echo "SECTIONS { \
// RUN:           .text_thumbfunc 0x1000 : { *(.text_thumbfunc) } \
// RUN:           .text_armfunc 0x1100c : { *(.text_armfunc) } \
// RUN:       }" > %tthumb_to_arm.script
// RUN: ld.lld -shared -Bsymbolic -script %tarm_to_thumb.script %t.o -o %tarm_to_thumb.so
// RUN: ld.lld -shared -Bsymbolic -script %tthumb_to_arm.script %t.o -o %tthumb_to_arm.so
// RUN: llvm-objdump -triple=armv7a-none-linux-gnueabi -d %tarm_to_thumb.so | FileCheck -check-prefix=ARM-TO-THUMB %s
// RUN: llvm-objdump -triple=thumbv7a-none-linux-gnueabi -d %tthumb_to_arm.so | FileCheck -check-prefix=THUMB-TO-ARM %s

.syntax unified

.arm
.section .text_armfunc, "ax", %progbits
.globl armfunc
armfunc:
	b	thumbfunc

.thumb
.section .text_thumbfunc, "ax", %progbits
.globl thumbfunc
.thumb_func
thumbfunc:
	b.w	armfunc

// ARM-TO-THUMB:      __ARMV7PILongThunk_thumbfunc:
// ARM-TO-THUMB-NEXT:     1004:        fd cf 0f e3         movw        r12, #65533
// ARM-TO-THUMB-NEXT:     1008:        00 c0 40 e3         movt        r12, #0

// THUMB-TO-ARM:      __ThumbV7PILongThunk_armfunc:
// THUMB-TO-ARM-NEXT:     1004:        4f f6 fc 7c         movw        r12, #65532
// THUMB-TO-ARM-NEXT:     1008:        c0 f2 00 0c         movt        r12, #0
