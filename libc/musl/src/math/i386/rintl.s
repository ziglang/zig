.global rintl
.type rintl,@function
rintl:
	fldt 4(%esp)
	frndint
	ret
