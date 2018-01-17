// REQUIRES: x86

// RUN: echo "SECTIONS { \
// RUN: .dynamic : { *(.dynamic) } \
// RUN: .non_ro : { . += 1; } \
// RUN: .jcr : { *(.jcr) } \
// RUN: } " > %t.script
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: not ld.lld --export-dynamic %t.o -o %t --script=%t.script 2>&1 | FileCheck %s

// RUN: echo "SECTIONS { \
// RUN: .dynamic : { *(.dynamic) } \
// RUN: .non_ro : { BYTE(1); } \
// RUN: .jcr : { *(.jcr) } \
// RUN: } " > %t2.script
// RUN: not ld.lld --export-dynamic %t.o -o %t --script=%t2.script 2>&1 | FileCheck %s

// CHECK: error: section: .jcr is not contiguous with other relro sections

.global _start
_start:

        // non-empty relro section
        .section .jcr, "aw", @progbits
        .quad 0
