.syntax unified
.global __syscall
.hidden __syscall
.type __syscall,%function
__syscall:
	mov ip,sp
	stmfd sp!,{r4,r5,r6,r7}
	mov r7,r0
	mov r0,r1
	mov r1,r2
	mov r2,r3
	ldmfd ip,{r3,r4,r5,r6}
	svc 0
	ldmfd sp!,{r4,r5,r6,r7}
	bx lr
