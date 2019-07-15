/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"log1p.S"
	.text
#ifdef __x86_64__
	.align 8
#else
	.align 4
#endif
	/* The fyl2xp1 can only be used for values in
	   -1 + sqrt(2) / 2 <= x <= 1 - sqrt(2) / 2
	   0.29 is a safe value.
	 */
limit:	.double 0.29
one:	.double 1.0
/*
 * Use the fyl2xp1 function when the argument is in the range -0.29 to 0.29,
 * otherwise fyl2x with the needed extra computation.
 */
.globl __MINGW_USYMBOL(log1p) 
	.def	__MINGW_USYMBOL(log1p);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(log1p):
#ifdef __x86_64__
	movsd	%xmm0,-16(%rsp)
	fldln2
	fldl	-16(%rsp)
	fxam
	fnstsw
	fld	%st
	sahf
	jc	3f	// in case x is NaN or ±Inf

4:	fabs
	fcompl	limit(%rip)
	fnstsw
	sahf
	jc	2f
	faddl	one(%rip)
	fyl2x
	fstpl	-16(%rsp)
	movsd	-16(%rsp),%xmm0
	ret

2:	fyl2xp1
	fstpl	-16(%rsp)
	movsd	-16(%rsp),%xmm0
	ret

3:	jp	4b	// in case x is ±Inf
	fstp	%st(1)
	fstp	%st(1)
	fstpl	-16(%rsp)
	movsd	-16(%rsp),%xmm0
	ret
#else
	fldln2
	fldl	4(%esp)
	fxam
	fnstsw
	fld	%st
	sahf
	jc	3f	// in case x is NaN or ±Inf

4:	fabs
	fcompl	limit
	fnstsw
	sahf
	jc	2f
	faddl	one
	fyl2x
	ret

2:	fyl2xp1
	ret

3:	jp	4b	// in case x is ±Inf
	fstp	%st(1)
	fstp	%st(1)
	ret
#endif
