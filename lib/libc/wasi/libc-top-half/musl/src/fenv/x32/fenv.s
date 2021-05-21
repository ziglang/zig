.global feclearexcept
.type feclearexcept,@function
feclearexcept:
		# maintain exceptions in the sse mxcsr, clear x87 exceptions
	mov %edi,%ecx
	and $0x3f,%ecx
	fnstsw %ax
	test %eax,%ecx
	jz 1f
	fnclex
1:	stmxcsr -8(%esp)
	and $0x3f,%eax
	or %eax,-8(%esp)
	test %ecx,-8(%esp)
	jz 1f
	not %ecx
	and %ecx,-8(%esp)
	ldmxcsr -8(%esp)
1:	xor %eax,%eax
	ret

.global feraiseexcept
.type feraiseexcept,@function
feraiseexcept:
	and $0x3f,%edi
	stmxcsr -8(%esp)
	or %edi,-8(%esp)
	ldmxcsr -8(%esp)
	xor %eax,%eax
	ret

.global __fesetround
.hidden __fesetround
.type __fesetround,@function
__fesetround:
	push %rax
	xor %eax,%eax
	mov %edi,%ecx
	fnstcw (%esp)
	andb $0xf3,1(%esp)
	or %ch,1(%esp)
	fldcw (%esp)
	stmxcsr (%esp)
	shl $3,%ch
	andb $0x9f,1(%esp)
	or %ch,1(%esp)
	ldmxcsr (%esp)
	pop %rcx
	ret

.global fegetround
.type fegetround,@function
fegetround:
	push %rax
	stmxcsr (%esp)
	pop %rax
	shr $3,%eax
	and $0xc00,%eax
	ret

.global fegetenv
.type fegetenv,@function
fegetenv:
	xor %eax,%eax
	fnstenv (%edi)
	stmxcsr 28(%edi)
	ret

.global fesetenv
.type fesetenv,@function
fesetenv:
	xor %eax,%eax
	inc %edi
	jz 1f
	fldenv -1(%edi)
	ldmxcsr 27(%edi)
	ret
1:	push %rax
	push %rax
	pushq $0xffff
	pushq $0x37f
	fldenv (%esp)
	pushq $0x1f80
	ldmxcsr (%esp)
	add $40,%esp
	ret

.global fetestexcept
.type fetestexcept,@function
fetestexcept:
	and $0x3f,%edi
	push %rax
	stmxcsr (%esp)
	pop %rsi
	fnstsw %ax
	or %esi,%eax
	and %edi,%eax
	ret
