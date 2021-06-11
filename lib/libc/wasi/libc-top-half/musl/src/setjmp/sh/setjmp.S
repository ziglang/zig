.global ___setjmp
.hidden ___setjmp
.global __setjmp
.global _setjmp
.global setjmp
.type   __setjmp, @function
.type   _setjmp,  @function
.type   setjmp,   @function
___setjmp:
__setjmp:
_setjmp:
setjmp:
#if __SH_FPU_ANY__ || __SH4__
	add   #52, r4
	fmov.s fr15, @-r4
	fmov.s fr14, @-r4
	fmov.s fr13, @-r4
	fmov.s fr12, @-r4
#else
	add   #36, r4
#endif
	sts.l  pr,   @-r4
	mov.l  r15,  @-r4
	mov.l  r14,  @-r4
	mov.l  r13,  @-r4
	mov.l  r12,  @-r4
	mov.l  r11,  @-r4
	mov.l  r10,  @-r4
	mov.l  r9,   @-r4
	mov.l  r8,   @-r4
	rts
	 mov  #0, r0
