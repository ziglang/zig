// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-linux-gnueabi %s -o %t
// RUN: echo "SECTIONS { \
// RUN:       . = SIZEOF_HEADERS; \
// RUN:       .text_low : { *(.text_low) *(.text_low2) } \
// RUN:       .text_high 0x2000000 : { *(.text_high) *(.text_high2) } \
// RUN:       } " > %t.script
// RUN: not ld.lld --script %t.script %t -o %t2 2>&1 | FileCheck %s

// CHECK: error: relocation R_ARM_THM_JUMP24 to far not supported for Armv5 or Armv6 targets

// Lie about our build attributes. Our triple is armv7a-linux-gnueabi but
// we are claiming to be Armv5. This can also happen with llvm-mc when we
// don't have any .eabi_attribute directives in the file or the
// --arm-add-build-attributes command line isn't used to add them from the
// triple.
 .eabi_attribute 6, 5           // Tag_cpu_arch 5 = v5TEJ
 .thumb
 .syntax unified
 .section .text_low, "ax", %progbits
 .thumb
 .globl _start
 .type _start, %function
_start:
 b.w far // Will produce relocation not supported in Armv5.

 .section .text_high, "ax", %progbits
 .globl far
 .type far, %function
far:
 bx lr
