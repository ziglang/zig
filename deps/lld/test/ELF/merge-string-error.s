// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: not ld.lld %t.o -o /dev/null -shared 2>&1 | FileCheck %s

        .section	.rodata.str1.1,"aMS",@progbits,1
	.asciz	"abc"

        .data
        .long .rodata.str1.1 + 4

// CHECK: merge-string-error.s.tmp.o:(.rodata.str1.1): offset is outside the section
