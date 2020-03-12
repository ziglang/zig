.global log2f
.type log2f,@function
log2f:
	fld1
	flds 4(%esp)
	fyl2x
	fstps 4(%esp)
	flds 4(%esp)
	ret
