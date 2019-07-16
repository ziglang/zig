.global __syscall
.hidden __syscall
.type __syscall,%function
__syscall:
	movem.l %d2-%d5,-(%sp)
	movem.l 20(%sp),%d0-%d5/%a0
	trap #0
	movem.l (%sp)+,%d2-%d5
	rts
