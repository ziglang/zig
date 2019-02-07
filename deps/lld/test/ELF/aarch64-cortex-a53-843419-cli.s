// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
// RUN: not ld.lld %t -fix-cortex-a53-843419 -o /dev/null 2>&1 | FileCheck %s

// CHECK: --fix-cortex-a53-843419 is only supported on AArch64 targets
.globl entry
.text
        .quad 0
entry:
        ret
