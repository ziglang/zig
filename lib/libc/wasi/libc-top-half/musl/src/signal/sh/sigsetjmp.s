.global sigsetjmp
.global __sigsetjmp
.type sigsetjmp,@function
.type __sigsetjmp,@function
sigsetjmp:
__sigsetjmp:
	tst r5, r5
	bt 9f

	mov r4, r6
	add #60, r6
	sts pr, r0
	mov.l r0, @r6
	mov.l r8, @(4+8,r6)

	mov.l 1f, r0
2:	bsrf r0
	 mov r4, r8

	mov r0, r5
	mov r8, r4
	mov r4, r6
	add #60, r6

	mov.l @r6, r0
	lds r0, pr

	mov.l 3f, r0
4:	braf r0
	 mov.l @(4+8,r4), r8

9:	mov.l 5f, r0
6:	braf r0
	 nop

.align 2
.hidden ___setjmp
1:	.long ___setjmp@PLT-(2b+4-.)
.hidden __sigsetjmp_tail
3:	.long __sigsetjmp_tail@PLT-(4b+4-.)
5:	.long ___setjmp@PLT-(6b+4-.)
