	.text
	.abiversion 2
	.type	c,@object               # @c
	.section	.tdata,"awT",@progbits
	.globl	c
c:
	.byte	97                      # 0x61
	.size	c, 1

	.type	s,@object               # @s
	.globl	s
	.p2align	1
s:
	.short	55                      # 0x37
	.size	s, 2

	.type	i,@object               # @i
	.globl	i
	.p2align	2
i:
	.long	55                      # 0x37
	.size	i, 4

	.type	l,@object               # @l
	.globl	l
	.p2align	3
l:
	.quad	55                      # 0x37
	.size	l, 8
