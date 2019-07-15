.hidden __hwcap

.global feclearexcept
.type feclearexcept,@function
feclearexcept:	
	mov 4(%esp),%ecx
	and $0x3f,%ecx
	fnstsw %ax
		# consider sse fenv as well if the cpu has XMM capability
	call 1f
1:	addl $__hwcap-1b,(%esp)
	pop %edx
	testl $0x02000000,(%edx)
	jz 2f
		# maintain exceptions in the sse mxcsr, clear x87 exceptions
	test %eax,%ecx
	jz 1f
	fnclex
1:	push %edx
	stmxcsr (%esp)
	pop %edx
	and $0x3f,%eax
	or %eax,%edx
	test %edx,%ecx
	jz 1f
	not %ecx
	and %ecx,%edx
	push %edx
	ldmxcsr (%esp)
	pop %edx
1:	xor %eax,%eax
	ret
		# only do the expensive x87 fenv load/store when needed
2:	test %eax,%ecx
	jz 1b
	not %ecx
	and %ecx,%eax
	test $0x3f,%eax
	jz 1f
	fnclex
	jmp 1b
1:	sub $32,%esp
	fnstenv (%esp)
	mov %al,4(%esp)
	fldenv (%esp)
	add $32,%esp
	xor %eax,%eax
	ret

.global feraiseexcept
.type feraiseexcept,@function
feraiseexcept:	
	mov 4(%esp),%eax
	and $0x3f,%eax
	sub $32,%esp
	fnstenv (%esp)
	or %al,4(%esp)
	fldenv (%esp)
	add $32,%esp
	xor %eax,%eax
	ret

.global __fesetround
.hidden __fesetround
.type __fesetround,@function
__fesetround:
	mov 4(%esp),%ecx
	push %eax
	xor %eax,%eax
	fnstcw (%esp)
	andb $0xf3,1(%esp)
	or %ch,1(%esp)
	fldcw (%esp)
		# consider sse fenv as well if the cpu has XMM capability
	call 1f
1:	addl $__hwcap-1b,(%esp)
	pop %edx
	testl $0x02000000,(%edx)
	jz 1f
	stmxcsr (%esp)
	shl $3,%ch
	andb $0x9f,1(%esp)
	or %ch,1(%esp)
	ldmxcsr (%esp)
1:	pop %ecx
	ret

.global fegetround
.type fegetround,@function
fegetround:
	push %eax
	fnstcw (%esp)
	pop %eax
	and $0xc00,%eax
	ret

.global fegetenv
.type fegetenv,@function
fegetenv:
	mov 4(%esp),%ecx
	xor %eax,%eax
	fnstenv (%ecx)
		# consider sse fenv as well if the cpu has XMM capability
	call 1f
1:	addl $__hwcap-1b,(%esp)
	pop %edx
	testl $0x02000000,(%edx)
	jz 1f
	push %eax
	stmxcsr (%esp)
	pop %edx
	and $0x3f,%edx
	or %edx,4(%ecx)
1:	ret

.global fesetenv
.type fesetenv,@function
fesetenv:
	mov 4(%esp),%ecx
	xor %eax,%eax
	inc %ecx
	jz 1f
	fldenv -1(%ecx)
	movl -1(%ecx),%ecx
	jmp 2f
1:	push %eax
	push %eax
	push %eax
	push %eax
	pushl $0xffff
	push %eax
	pushl $0x37f
	fldenv (%esp)
	add $28,%esp
		# consider sse fenv as well if the cpu has XMM capability
2:	call 1f
1:	addl $__hwcap-1b,(%esp)
	pop %edx
	testl $0x02000000,(%edx)
	jz 1f
		# mxcsr := same rounding mode, cleared exceptions, default mask
	and $0xc00,%ecx
	shl $3,%ecx
	or $0x1f80,%ecx
	mov %ecx,4(%esp)
	ldmxcsr 4(%esp)
1:	ret

.global fetestexcept
.type fetestexcept,@function
fetestexcept:
	mov 4(%esp),%ecx
	and $0x3f,%ecx
	fnstsw %ax
		# consider sse fenv as well if the cpu has XMM capability
	call 1f
1:	addl $__hwcap-1b,(%esp)
	pop %edx
	testl $0x02000000,(%edx)
	jz 1f
	stmxcsr 4(%esp)
	or 4(%esp),%eax
1:	and %ecx,%eax
	ret
