# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64-unknown-cloudabi %s -o %t.o
# RUN: ld.lld --hash-style=sysv -pie %t.o -o %t
# RUN: llvm-readobj -r %t | FileCheck %s

# If we're addressing a global relatively through the GOT, we still need to
# emit a relocation for the entry in the GOT itself.
# CHECK: Relocations [
# CHECK:   Section (4) .rela.dyn {
# CHECK:     0x{{[0-9A-F]+}} R_AARCH64_RELATIVE - 0x{{[0-9A-F]+}}
# CHECK:   }
# CHECK: ]

	.globl	_start
	.type	_start,@function
_start:
	adrp	x8, :got:i
	ldr	x8, [x8, :got_lo12:i]

	.type	i,@object
	.comm	i,4,4
