.global log10l
.type log10l,@function
log10l:
	fldlg2
	fldt 8(%esp)
	fyl2x
	ret
