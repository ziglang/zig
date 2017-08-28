# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-cloudabi %s -o %t1.o
# RUN: ld.lld -pie %t1.o -o %t
# RUN: llvm-readobj -r %t | FileCheck %s

# Bug 27174: R_X86_64_TPOFF32 and R_X86_64_GOTTPOFF relocations should
# be eliminated when building a PIE executable, as the static TLS layout
# is fixed.
#
# CHECK:      Relocations [
# CHECK-NEXT: ]

	.globl	_start
_start:
	movq	%fs:0, %rax
	movl	$3, i@TPOFF(%rax)

	movq	%fs:0, %rdx
	movq	i@GOTTPOFF(%rip), %rcx
	movl	$3, (%rdx,%rcx)

	.section	.tbss.i,"awT",@nobits
	.globl	i
i:
	.long	0
	.size	i, 4
