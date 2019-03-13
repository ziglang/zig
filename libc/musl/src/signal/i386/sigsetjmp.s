.global sigsetjmp
.global __sigsetjmp
.type sigsetjmp,@function
.type __sigsetjmp,@function
sigsetjmp:
__sigsetjmp:
	mov 8(%esp),%ecx
	jecxz 1f

	mov 4(%esp),%eax
	popl 24(%eax)
	mov %ebx,28+8(%eax)
	mov %eax,%ebx

.hidden ___setjmp
	call ___setjmp

	pushl 24(%ebx)
	mov %ebx,4(%esp)
	mov %eax,8(%esp)
	mov 28+8(%ebx),%ebx

.hidden __sigsetjmp_tail
	jmp __sigsetjmp_tail

1:	jmp ___setjmp
