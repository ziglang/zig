// RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
// RUN: ld.lld -shared %t.o -o %t.so
// RUN: llvm-readobj -t -r -dyn-symbols %t.so | FileCheck %s
// REQUIRES: ppc

// When we create the TOC reference in the shared library, make sure that the
// R_PPC64_RELATIVE relocation uses the correct (non-zero) offset.

        .globl  foo
        .align  2
        .type   foo,@function
        .section        .opd,"aw",@progbits
foo:                                    # @foo
        .align  3
        .quad   .Lfunc_begin0
        .quad   .TOC.@tocbase
        .quad   0
        .text
.Lfunc_begin0:
        blr

// CHECK: 0x20000 R_PPC64_RELATIVE - 0x10000
// CHECK: 0x20008 R_PPC64_RELATIVE - 0x8000

// CHECK: Name: foo
// CHECK-NEXT: Value: 0x20000

