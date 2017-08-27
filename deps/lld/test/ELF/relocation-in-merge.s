// REQUIRES: x86
// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=x86_64-pc-linux
// RUN: ld.lld %t.o -o %t -shared
// RUN: llvm-objdump -section-headers %t | FileCheck %s

// Test that we accept this by just not merging the section.
// CHECK:  .foo          00000008

bar:
        .section	.foo,"aM",@progbits,8
        .long bar - .
        .long bar - .
