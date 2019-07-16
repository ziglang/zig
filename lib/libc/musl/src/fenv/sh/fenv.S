#if __SH_FPU_ANY__ || __SH4__

.global fegetround
.type   fegetround, @function
fegetround:
	sts fpscr, r0
	rts
	 and #3, r0

.global __fesetround
.hidden __fesetround
.type   __fesetround, @function
__fesetround:
	sts fpscr, r0
	or  r4, r0
	lds r0, fpscr
	rts
	 mov #0, r0

.global fetestexcept
.type   fetestexcept, @function
fetestexcept:
	sts fpscr, r0
	and r4, r0
	rts
	 and #0x7c, r0

.global feclearexcept
.type   feclearexcept, @function
feclearexcept:
	mov r4, r0
	and #0x7c, r0
	not r0, r4
	sts fpscr, r0
	and r4, r0
	lds r0, fpscr
	rts
	 mov #0, r0

.global feraiseexcept
.type   feraiseexcept, @function
feraiseexcept:
	mov r4, r0
	and #0x7c, r0
	sts fpscr, r4
	or  r4, r0
	lds r0, fpscr
	rts
	 mov #0, r0

.global fegetenv
.type   fegetenv, @function
fegetenv:
	sts fpscr, r0
	mov.l r0, @r4
	rts
	 mov #0, r0

.global fesetenv
.type   fesetenv, @function
fesetenv:
	mov r4, r0
	cmp/eq #-1, r0
	bf 1f

	! the default environment is complicated by the fact that we need to
	! preserve the current precision bit, which we do not know a priori
	sts fpscr, r0
	mov #8, r1
	swap.w r1, r1
	bra 2f
	 and r1, r0

1:	mov.l @r4, r0      ! non-default environment
2:	lds r0, fpscr
	rts
	 mov #0, r0

#endif
