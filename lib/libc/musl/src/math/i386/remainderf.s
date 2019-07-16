.global remainderf
.type remainderf,@function
remainderf:
.weak dremf
.type dremf,@function
dremf:
	flds 8(%esp)
	flds 4(%esp)
1:	fprem1
	fnstsw %ax
	sahf
	jp 1b
	fstp %st(1)
	ret
