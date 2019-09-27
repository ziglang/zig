// REQUIRES: arm
// RUN: llvm-mc %s -triple=armv7-unknown-linux-gnueabi -filetype=obj --arm-add-build-attributes -o %t.o
// RUN: echo "SECTIONS { \
// RUN:          .text : { *(.text) } \
// RUN:          .prel.test : { *(.ARM.exidx) } \
// RUN:          .TEST1 : { *(.TEST1) } } " > %t.script
// RUN: ld.lld --script %t.script %t.o -o %t
// RUN: llvm-readobj -S --section-data %t | FileCheck --check-prefix=CHECK %s

// The R_ARM_PREL31 relocation is used in by the .ARM.exidx exception tables
// bit31 of the place denotes whether the field is an inline table entry
// (bit31=1) or relocation (bit31=0)
// The linker must preserve the value of bit31

// This test case is adapted from llvm/test/MC/ARM/eh-compact-pr0.s
// We use a linker script to place the .ARM.exidx sections in between
// the code sections so that we can test positive and negative offsets
 .syntax unified

 .section .TEST1, "ax",%progbits
 .globl _start
 .align 2
 .type  _start,%function
_start:
 .fnstart
 .save   {r11, lr}
 push    {r11, lr}
 .setfp  r11, sp
 mov     r11, sp
 pop     {r11, lr}
 mov     pc, lr
 .fnend

 .section .text, "ax",%progbits
// The generated .ARM.exidx section will refer to the personality
// routine __aeabi_unwind_cpp_pr0. Provide a dummy implementation
// to stop an undefined symbol error
 .globl __aeabi_unwind_cpp_pr0
 .align 2
 .type __aeabi_unwind_cpp_pr0,%function
__aeabi_unwind_cpp_pr0:
 .fnstart
 bx lr
 .fnend

// The expected value of the exception table is
// Word0 0 in bit 31, -4 encoded in 31-bit signed offset
// Word1 Inline table entry EHT Inline Personality Routine #0
// Word3 0 in bit 31, +10 encoded in 31-bit signed offset
// Word4 Inline table entry EHT Inline Personality Routine #0
// set vsp = r11
// pop r11, r14
// Word5 Sentinel +18 EXIDX_CANTUNWIND

// CHECK:  Name: .prel.test
// CHECK:  SectionData (
// CHECK:     0000: FCFFFF7F B0B0B080 10000000 80849B80
// CHECK:     0010: 18000000 01000000
// CHECK:  )
