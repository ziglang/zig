.global remainderl
.type remainderl,@function
remainderl:
	fldt 16(%esp)
	fldt 4(%esp)
1:	fprem1
	fnstsw %ax
	sahf
	jp 1b
	fstp %st(1)
	ret
