// RUN: llvm-mc -filetype=obj -triple=mips64-unknown-freebsd %s -o %t.o
// RUN: ld.lld --eh-frame-hdr %t.o -o %t | FileCheck -allow-empty %s

// REQUIRES: mips

// CHECK-NOT: corrupted or unsupported CIE information
// CHECK-NOT: corrupted CIE

.global __start
__start:

.section        .eh_frame,"aw",@progbits
        .4byte  9
        .4byte  0x0
        .byte   0x1
        .string ""
        .uleb128 0x1
        .sleb128 -4
        .byte   0x1f
