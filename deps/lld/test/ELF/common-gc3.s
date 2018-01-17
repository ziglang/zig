# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t1 --gc-sections
# RUN: llvm-objdump -s %t1 | FileCheck %s

# CHECK:      Contents of section .noalloc:
# 0000 00000000 00000000                    ........

	.section	.text._start,"ax",@progbits
	.globl	_start
_start:
	retq

	.type	unused,@object
	.comm	unused,4,4

	.section	.noalloc,"",@progbits
	.quad	unused
