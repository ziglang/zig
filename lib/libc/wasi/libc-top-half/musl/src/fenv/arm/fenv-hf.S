#if __ARM_PCS_VFP

.syntax unified
.fpu vfp

.global fegetround
.type fegetround,%function
fegetround:
	fmrx r0, fpscr
	and r0, r0, #0xc00000
	bx lr

.global __fesetround
.hidden __fesetround
.type __fesetround,%function
__fesetround:
	fmrx r3, fpscr
	bic r3, r3, #0xc00000
	orr r3, r3, r0
	fmxr fpscr, r3
	mov r0, #0
	bx lr

.global fetestexcept
.type fetestexcept,%function
fetestexcept:
	and r0, r0, #0x1f
	fmrx r3, fpscr
	and r0, r0, r3
	bx lr

.global feclearexcept
.type feclearexcept,%function
feclearexcept:
	and r0, r0, #0x1f
	fmrx r3, fpscr
	bic r3, r3, r0
	fmxr fpscr, r3
	mov r0, #0
	bx lr

.global feraiseexcept
.type feraiseexcept,%function
feraiseexcept:
	and r0, r0, #0x1f
	fmrx r3, fpscr
	orr r3, r3, r0
	fmxr fpscr, r3
	mov r0, #0
	bx lr

.global fegetenv
.type fegetenv,%function
fegetenv:
	fmrx r3, fpscr
	str r3, [r0]
	mov r0, #0
	bx lr

.global fesetenv
.type fesetenv,%function
fesetenv:
	cmn r0, #1
	moveq r3, #0
	ldrne r3, [r0]
	fmxr fpscr, r3
	mov r0, #0
	bx lr

#endif
