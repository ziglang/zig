.global rintl
.type rintl,@function
rintl:
	fldt 8(%rsp)
	frndint
	ret
