# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64-unknown-cloudabi %s -o %t1.o
# RUN: ld.lld -pie %t1.o -o %t
# RUN: llvm-readobj -r %t | FileCheck %s

# Similar to bug 27174: R_AARCH64_TLSLE_*TPREL* relocations should be
# eliminated when building a PIE executable, as the static TLS layout is
# fixed.
#
# CHECK:      Relocations [
# CHECK-NEXT: ]

	.globl	_start
_start:
	# Accessing the variable directly.
	add	x11, x8, :tprel_hi12:i
	add	x11, x11, :tprel_lo12_nc:i

	# Accessing the variable through the GOT.
	adrp	x10, :gottprel:i
	mrs	x8, TPIDR_EL0
	ldr	x10, [x10, :gottprel_lo12:i]

	.section	.tbss.i,"awT",@nobits
	.globl	i
i:
	.word	0
	.size	i, 4
