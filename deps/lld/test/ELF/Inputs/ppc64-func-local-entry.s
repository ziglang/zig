	.text
	.abiversion 2
	.globl	foo_external_same       # -- Begin function foo_external_same
	.p2align	4
	.type	foo_external_same,@function
foo_external_same:                      # @foo_external_same
.Lfunc_begin0:
# %bb.0:                                # %entry
	add 3, 4, 3
	extsw 3, 3
	blr
	.long	0
	.quad	0
.Lfunc_end0:
	.size	foo_external_same, .Lfunc_end0-.Lfunc_begin0
                                        # -- End function
