.global log10f
.type log10f,@function
log10f:
	fldlg2
	flds 4(%esp)
	fyl2x
	ret
