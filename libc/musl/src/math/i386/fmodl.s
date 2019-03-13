.global fmodl
.type fmodl,@function
fmodl:
	fldt 16(%esp)
	fldt 4(%esp)
1:	fprem
	fnstsw %ax
	sahf
	jp 1b
	fstp %st(1)
	ret
