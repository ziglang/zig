.global atanl
.type atanl,@function
atanl:
	fldt 8(%esp)
	fld1
	fpatan
	ret
