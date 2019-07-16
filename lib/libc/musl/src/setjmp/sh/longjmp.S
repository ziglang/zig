.global _longjmp
.global longjmp
.type   _longjmp, @function
.type   longjmp,  @function
_longjmp:
longjmp:
	mov.l  @r4+, r8
	mov.l  @r4+, r9
	mov.l  @r4+, r10
	mov.l  @r4+, r11
	mov.l  @r4+, r12
	mov.l  @r4+, r13
	mov.l  @r4+, r14
	mov.l  @r4+, r15
	lds.l  @r4+, pr
#if __SH_FPU_ANY__ || __SH4__
	fmov.s @r4+, fr12
	fmov.s @r4+, fr13
	fmov.s @r4+, fr14
	fmov.s @r4+, fr15
#endif

	tst  r5, r5
	movt r0
	add  r5, r0

	rts
	 nop
