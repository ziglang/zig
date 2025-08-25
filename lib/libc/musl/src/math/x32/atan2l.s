.global atan2l
.type atan2l,@function
atan2l:
	fldt 8(%esp)
	fldt 24(%esp)
	fpatan
	ret
