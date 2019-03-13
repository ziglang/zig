.global pipe
.type   pipe, @function
pipe:
	mov    #42, r3
	trapa  #31

	! work around hardware bug
	or     r0, r0
	or     r0, r0
	or     r0, r0
	or     r0, r0
	or     r0, r0

	cmp/pz r0
	bt     1f

	mov.l  L1, r1
	braf   r1
	 mov   r0, r4

1:	mov.l  r0, @(0,r4)
	mov.l  r1, @(4,r4)
	rts
	 mov   #0, r0

.align 2
L1:	.long __syscall_ret@PLT-(1b-.)
