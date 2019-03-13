.global atan2l
.type atan2l,@function
atan2l:
	fldt 8(%rsp)
	fldt 24(%rsp)
	fpatan
	ret
