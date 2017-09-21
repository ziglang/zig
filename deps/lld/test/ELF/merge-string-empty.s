// Ensure that a mergeable string with size 0 does not cause any issue.

// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t

.globl _start, s
.section .rodata.str1.1,"aMS",@progbits,1
s:
.text
_start:
	.quad s
