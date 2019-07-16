.global __syscall
.hidden __syscall
.type   __syscall, @function
__syscall:
	! The kernel syscall entry point documents that the trap number indicates
	! the number of arguments being passed, but it then ignores that information.
	! Since we do not actually know how many arguments are being passed, we will
	! say there are six, since that is the maximum we support here.
	mov r4, r3
	mov r5, r4
	mov r6, r5
	mov r7, r6
	mov.l @r15, r7
	mov.l @(4,r15), r0
	mov.l @(8,r15), r1
	trapa #31
	or r0, r0
	or r0, r0
	or r0, r0
	or r0, r0
	or r0, r0
	rts
	 nop
