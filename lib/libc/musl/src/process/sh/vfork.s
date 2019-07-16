.global vfork
.type vfork,@function
vfork:
	mov #95, r3
	add r3, r3

	trapa #31
	or    r0, r0
	or    r0, r0
	or    r0, r0
	or    r0, r0
	or    r0, r0

	mov r0, r4
	mov.l 1f, r0
2:	braf r0
	 nop
	.align 2
	.hidden __syscall_ret
1:	.long __syscall_ret@PLT-(2b+4-.)
