.global remainderl
.type remainderl,@function
remainderl:
	fldt 24(%esp)
	fldt 8(%esp)
1:	fprem1
	fnstsw %ax
	testb $4,%ah
	jnz 1b
	fstp %st(1)
	ret
