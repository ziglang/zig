.global log2l
.type log2l,@function
log2l:
	fld1
	fldt 8(%esp)
	fyl2x
	ret
