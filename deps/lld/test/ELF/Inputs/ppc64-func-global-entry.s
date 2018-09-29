	.text
	.abiversion 2
	.globl	foo_external_diff       # -- Begin function foo_external_diff
	.p2align	4
	.type	foo_external_diff,@function
foo_external_diff:                      # @foo_external_diff
.Lfunc_begin0:
.Lfunc_gep0:
	addis 2, 12, .TOC.-.Lfunc_gep0@ha
	addi 2, 2, .TOC.-.Lfunc_gep0@l
.Lfunc_lep0:
	.localentry	foo_external_diff, .Lfunc_lep0-.Lfunc_gep0
# %bb.0:                                # %entry
	addis 5, 2, .LC0@toc@ha
	add 3, 4, 3
	ld 5, .LC0@toc@l(5)
	lwz 5, 0(5)
	add 3, 3, 5
	extsw 3, 3
	blr
	.long	0
	.quad	0
.Lfunc_end0:
	.size	foo_external_diff, .Lfunc_end0-.Lfunc_begin0
                                        # -- End function
	.section	.toc,"aw",@progbits
.LC0:
	.tc glob2[TC],glob2
	.type	glob2,@object           # @glob2
	.data
	.globl	glob2
	.p2align	2
glob2:
	.long	10                      # 0xa
	.size	glob2, 4
