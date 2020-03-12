.global log10
.type log10,@function
log10:
	fldlg2
	fldl 4(%esp)
	fyl2x
	fstpl 4(%esp)
	fldl 4(%esp)
	ret
