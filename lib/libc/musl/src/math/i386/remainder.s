.global remainder
.type remainder,@function
remainder:
.weak drem
.type drem,@function
drem:
	fldl 12(%esp)
	fldl 4(%esp)
1:	fprem1
	fnstsw %ax
	sahf
	jp 1b
	fstp %st(1)
	ret
