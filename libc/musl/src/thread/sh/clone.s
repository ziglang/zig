.text
.global __clone
.hidden __clone
.type   __clone, @function
__clone:
! incoming: fn stack flags arg ptid tls      ctid
!           r4 r5    r6    r7  @r15 @(4,r15) @(8,r15)

	mov   #-16, r0
	and   r0, r5

	mov   r4, r1         ! r1 = fn
	mov   r7, r2         ! r2 = arg

	mov   #120,     r3   ! r3 = __NR_clone
	mov   r6,       r4   ! r4 = flags
	!mov  r5,       r5   ! r5 = stack
	mov.l @r15,     r6   ! r6 = ptid
	mov.l @(8,r15), r7   ! r7 = ctid
	mov.l @(4,r15), r0   ! r0 = tls
	trapa #31

	or r0, r0
	or r0, r0
	or r0, r0
	or r0, r0
	or r0, r0

	cmp/eq #0, r0
	bt     1f

	! we are the parent, return
	rts
	 nop

1:	! we are the child, call fn(arg)
	mov.l  1f, r0
	mov    r1, r5
	bsrf   r0
	 mov    r2, r4

2:	mov   #1, r3   ! __NR_exit
	mov   r0, r4
	trapa #31

	or   r0, r0
	or   r0, r0
	or   r0, r0
	or   r0, r0
	or   r0, r0

.align 2
.hidden __shcall
1:	.long __shcall@PCREL+(.-2b)
