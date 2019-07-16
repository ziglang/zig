.global floorl
.type floorl,@function
floorl:
	fldt 8(%esp)
1:	mov $0x7,%al
1:	fstcw 8(%esp)
	mov 9(%esp),%ah
	mov %al,9(%esp)
	fldcw 8(%esp)
	frndint
	mov %ah,9(%esp)
	fldcw 8(%esp)
	ret

.global ceill
.type ceill,@function
ceill:
	fldt 8(%esp)
	mov $0xb,%al
	jmp 1b

.global truncl
.type truncl,@function
truncl:
	fldt 8(%esp)
	mov $0xf,%al
	jmp 1b
