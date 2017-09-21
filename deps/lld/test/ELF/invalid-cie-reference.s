// REQUIRES: x86

// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
// RUN: not ld.lld %t -o %t2 2>&1 | FileCheck %s

        .section .eh_frame
        .long 0x14
        .long 0x0
        .byte 0x01
        .byte 0x7a
        .byte 0x52
        .byte 0x00
        .byte 0x01
        .byte 0x78
        .byte 0x10
        .byte 0x01
        .byte 0x1b
        .byte 0x0c
        .byte 0x07
        .byte 0x08
        .byte 0x90
        .byte 0x01
        .short 0x0

        .long 0x14
        .long 0x1b
        .long .text
        .long 0x0
        .long 0x0
        .long 0x0

// CHECK: invalid CIE reference
