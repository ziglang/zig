# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64 %s -o %t
# RUN: ld.lld -r %t -o %t2
# RUN: llvm-objdump -s -section=.symtab %t2 | FileCheck %s

.text
.abiversion 2
.globl  _start
.p2align	2
.type   _start,@function

_start:
.Lfunc_begin0:
.Lfunc_gep0:
	addis 2, 12, .TOC.-.Lfunc_gep0@ha
	addi 2, 2, .TOC.-.Lfunc_gep0@l
.Lfunc_lep0:
	.localentry	_start, .Lfunc_lep0-.Lfunc_gep0
	# The code below is not important, it just needs to access some
	# global data or function, in order to use the TOC.
	# In this case, it performs the following:
	# g += 10;
	# Also note that this code is not intended to be run, but only
	# to check if the linker will preserve the localentry info.
	addis 3, 2, g@toc@ha
	addi 3, 3, g@toc@l
	lwz 4, 0(3)
	addi 4, 4, 10
	stw 4, 0(3)
	blr
	.long	0
	.quad	0
.Lfunc_end0:
	.size   _start, .Lfunc_end0-.Lfunc_begin0

	.type	g,@object               # @g
	.lcomm	g,4,4

// We expect the st_other byte to be 0x60:
// localentry = 011 (gep + 2 instructions), reserved = 000,
// visibility = 00 (STV_DEFAULT)
// Currently, llvm-objdump does not support displaying
// st_other's PPC64 specific flags, thus we check the
// result of the hexdump of .symtab section.

// CHECK: 0070 00000000 00000000 00000009 12600001
