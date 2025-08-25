.global atan2l
.type atan2l,@function
atan2l:
	fldt 4(%esp)
	fldt 16(%esp)
	fpatan
	ret
