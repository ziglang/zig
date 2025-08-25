.global log2l
.type log2l,@function
log2l:
	fld1
	fldt 8(%rsp)
	fyl2x
	ret
