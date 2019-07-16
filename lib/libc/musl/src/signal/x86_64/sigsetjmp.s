.global sigsetjmp
.global __sigsetjmp
.type sigsetjmp,@function
.type __sigsetjmp,@function
sigsetjmp:
__sigsetjmp:
	test %esi,%esi
	jz 1f

	popq 64(%rdi)
	mov %rbx,72+8(%rdi)
	mov %rdi,%rbx

	call setjmp@PLT

	pushq 64(%rbx)
	mov %rbx,%rdi
	mov %eax,%esi
	mov 72+8(%rbx),%rbx

.hidden __sigsetjmp_tail
	jmp __sigsetjmp_tail

1:	jmp setjmp@PLT
