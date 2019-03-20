// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-linux-gnu %s -o %t
// RUN: ld.lld --just-symbols %t -fix-cortex-a53-843419 -o %t.axf
// RUN: llvm-readobj --symbols %t.axf | FileCheck %s

// Check that we can gracefully handle --just-symbols, which gives a local
// absolute mapping symbol (with no Section). Previously we assumed that all
// mapping symbols were defined relative to a section and assert failed.

        .text
        .global _start
        .type _start, %function
_start: ret

// CHECK:     Name: $x.0
// CHECK-NEXT:     Value: 0x0
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local (0x0)
// CHECK-NEXT:     Type: None (0x0)
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: Absolute (0xFFF1)
// CHECK-NEXT:   }
