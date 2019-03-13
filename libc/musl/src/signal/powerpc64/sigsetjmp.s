	.global sigsetjmp
	.global __sigsetjmp
	.type sigsetjmp,%function
	.type __sigsetjmp,%function
	.hidden __setjmp_toc
sigsetjmp:
__sigsetjmp:
	addis 2, 12, .TOC.-__sigsetjmp@ha
	addi  2,  2, .TOC.-__sigsetjmp@l
	ld    5, 24(1)   # load from the TOC slot in the caller's stack frame
	b     1f

	.localentry sigsetjmp,.-sigsetjmp
	.localentry __sigsetjmp,.-__sigsetjmp
	mr    5,  2

1:
	cmpwi cr7, 4, 0
	beq-  cr7, __setjmp_toc

	mflr  6
	std   6, 512(3)
	std   2, 512+16(3)
	std  16, 512+24(3)
	mr   16, 3

	bl __setjmp_toc

	mr   4,  3
	mr   3, 16
	ld   5, 512(3)
	mtlr 5
	ld   2, 512+16(3)
	ld  16, 512+24(3)

.hidden __sigsetjmp_tail
	b __sigsetjmp_tail
