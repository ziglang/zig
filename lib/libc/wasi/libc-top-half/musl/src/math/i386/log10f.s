.global log10f
.type log10f,@function
log10f:
	fldlg2
	flds 4(%esp)
	fyl2x
	fstps 4(%esp)
	flds 4(%esp)
	ret
