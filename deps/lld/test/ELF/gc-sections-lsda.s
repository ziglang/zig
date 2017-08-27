// REQUIRES: x86

// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=x86_64-pc-linux
// RUN: ld.lld -shared --gc-sections %t.o -o %t

// Test that we handle .eh_frame keeping sections alive. We could be more
// precise and gc the entire contents of this file, but test that at least
// we are consistent: if we keep .abc, we have to keep .foo

// RUN: llvm-readobj -s %t | FileCheck %s
// CHECK:  Name: .abc
// CHECK: Name: .foo

        .cfi_startproc
        .cfi_lsda 0x1b,zed
        .cfi_endproc
        .section        .abc,"a"
zed:
        .long   bar-.
        .section        .foo,"ax"
bar:
