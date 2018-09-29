	.text
	.abiversion 2
	.type	a,@object # @a
	.type	b,@object # @a
	.type	c,@object # @a
	.section	.tdata,"awT",@progbits
	.globl	a
a:
	.long	10                      # 0xa
	.size	a, 4

	.globl	b
b:
	.long	10                      # 0xa
	.size	b, 4

	.globl	c
c:
	.long	10                      # 0xa
	.size	c, 4
