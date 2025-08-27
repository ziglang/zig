/* zig patch: removed `floorl` in favor of using zig compiler_rt's implementations */

1:	fstcw 8(%rsp)
	mov 9(%rsp),%ah
	mov %al,9(%rsp)
	fldcw 8(%rsp)
	frndint
	mov %ah,9(%rsp)
	fldcw 8(%rsp)
	ret

.global ceill
.type ceill,@function
ceill:
	fldt 8(%rsp)
	mov $0xb,%al
	jmp 1b

.global truncl
.type truncl,@function
truncl:
	fldt 8(%rsp)
	mov $0xf,%al
	jmp 1b
