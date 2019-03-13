.global fmodf
.type fmodf,@function
fmodf:
	flds 8(%esp)
	flds 4(%esp)
1:	fprem
	fnstsw %ax
	sahf
	jp 1b
	fstp %st(1)
	ret
