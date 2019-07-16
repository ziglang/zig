.global log10l
.type log10l,@function
log10l:
	fldlg2
	fldt 4(%esp)
	fyl2x
	ret
