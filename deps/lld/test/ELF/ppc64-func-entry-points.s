// REQUIRES: ppc

// RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %p/Inputs/ppc64-func-global-entry.s -o %t2.o
// RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %p/Inputs/ppc64-func-local-entry.s -o %t3.o
// RUN: ld.lld -dynamic-linker /lib64/ld64.so.2 %t.o %t2.o %t3.o -o %t
// RUN: llvm-objdump -d %t | FileCheck %s

// RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %p/Inputs/ppc64-func-global-entry.s -o %t2.o
// RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %p/Inputs/ppc64-func-local-entry.s -o %t3.o
// RUN: ld.lld -dynamic-linker /lib64/ld64.so.2 %t.o %t2.o %t3.o -o %t
// RUN: llvm-objdump -d %t | FileCheck %s

	.text
	.abiversion 2
	.globl	_start                    # -- Begin function _start
	.p2align	4
	.type	_start,@function
_start:                                   # @_start
.Lfunc_begin0:
.Lfunc_gep0:
	addis 2, 12, .TOC.-.Lfunc_gep0@ha
	addi 2, 2, .TOC.-.Lfunc_gep0@l
.Lfunc_lep0:
	.localentry	_start, .Lfunc_lep0-.Lfunc_gep0
# %bb.0:                                # %entry
	mflr 0
	std 0, 16(1)
	stdu 1, -48(1)
	li 3, 1
	li 4, 1
	std 30, 32(1)                   # 8-byte Folded Spill
	bl foo_external_same
	nop
	mr 30, 3
	li 3, 2
	li 4, 2
	bl foo_external_diff
	nop
	addis 4, 2, .LC0@toc@ha
	add 3, 3, 30
	ld 30, 32(1)                    # 8-byte Folded Reload
	ld 4, .LC0@toc@l(4)
	lwz 4, 0(4)
	add 3, 3, 4
	extsw 3, 3
	addi 1, 1, 48
	ld 0, 16(1)
	li 0, 1
	sc
	.long	0
	.quad	0
.Lfunc_end0:
	.size	_start, .Lfunc_end0-.Lfunc_begin0
                                        # -- End function
	.section	.toc,"aw",@progbits
.LC0:
	.tc glob[TC],glob
	.type	glob,@object            # @glob
	.data
	.globl	glob
	.p2align	2
glob:
	.long	10                      # 0xa
	.size	glob, 4

# Check that foo_external_diff has a global entry point and we branch to
# foo_external_diff+8. Also check that foo_external_same has no global entry
# point and we branch to start of foo_external_same.

// CHECK: _start:
// CHECK: 10010020:       {{.*}}     bl .+144
// CHECK: 10010034:       {{.*}}     bl .+84
// CHECK: foo_external_diff:
// CHECK-NEXT: 10010080:       {{.*}}     addis 2, 12, 2
// CHECK-NEXT: 10010084:       {{.*}}     addi 2, 2, 32640
// CHECK-NEXT: 10010088:       {{.*}}     nop
// CHECK: foo_external_same:
// CHECK-NEXT: 100100b0:       {{.*}}     add 3, 4, 3
