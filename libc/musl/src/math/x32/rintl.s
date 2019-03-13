.global rintl
.type rintl,@function
rintl:
	fldt 8(%esp)
	frndint
	ret
