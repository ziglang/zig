/* zig patch: removed `floorl` and `floorf` in favor of using zig compiler_rt's implementations */

1:	fstcw 4(%esp)
	mov 5(%esp),%ah
	mov %al,5(%esp)
	fldcw 4(%esp)
	frndint
	mov %ah,5(%esp)
	fldcw 4(%esp)
	ret

.global ceil
.type ceil,@function
ceil:
	fldl 4(%esp)
	mov $0xb,%al
	jmp 1b

.global ceilf
.type ceilf,@function
ceilf:
	flds 4(%esp)
	mov $0xb,%al
	jmp 1b

.global ceill
.type ceill,@function
ceill:
	fldt 4(%esp)
	mov $0xb,%al
	jmp 1b

.global trunc
.type trunc,@function
trunc:
	fldl 4(%esp)
	mov $0xf,%al
	jmp 1b

.global truncf
.type truncf,@function
truncf:
	flds 4(%esp)
	mov $0xf,%al
	jmp 1b

.global truncl
.type truncl,@function
truncl:
	fldt 4(%esp)
	mov $0xf,%al
	jmp 1b
