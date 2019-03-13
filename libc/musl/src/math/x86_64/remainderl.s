.global remainderl
.type remainderl,@function
remainderl:
	fldt 24(%rsp)
	fldt 8(%rsp)
1:	fprem1
	fnstsw %ax
	testb $4,%ah
	jnz 1b
	fstp %st(1)
	ret
