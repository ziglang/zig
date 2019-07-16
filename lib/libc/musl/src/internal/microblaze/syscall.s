.global __syscall
.hidden __syscall
.type   __syscall,@function
__syscall:
	addi    r12, r5, 0              # Save the system call number
	add     r5, r6, r0              # Shift the arguments, arg1
	add     r6, r7, r0              # arg2
	add     r7, r8, r0              # arg3
	add     r8, r9, r0              # arg4
	add     r9, r10, r0             # arg5
	lwi     r10, r1, 28             # Get arg6.
	brki    r14, 0x8                # syscall
	rtsd    r15, 8
	nop
