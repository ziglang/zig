.global atanl
.type atanl,@function
atanl:
	fldt 4(%esp)
	fld1
	fpatan
	ret
