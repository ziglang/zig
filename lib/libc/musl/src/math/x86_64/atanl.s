.global atanl
.type atanl,@function
atanl:
	fldt 8(%rsp)
	fld1
	fpatan
	ret
