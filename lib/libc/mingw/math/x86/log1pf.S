/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"log1pf.S"
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
limit:	.float 0.29
one:	.float 1.0
/*
 * Use the fyl2xp1 function when the argument is in the range -0.29 to 0.29,
 * otherwise fyl2x with the needed extra computation.
 */
.globl __MINGW_USYMBOL(log1pf)
	.def	__MINGW_USYMBOL(log1pf);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(log1pf):
#ifdef __x86_64__
	movss	%xmm0,-12(%rsp)
	fldln2
	flds	-12(%rsp)
	fxam
	fnstsw
	fld	%st
	sahf
	jc	3f		// in case x is NaN or ±Inf

4:	fabs
	fcomps	limit(%rip)
	fnstsw
	sahf
	jc	2f
	fadds	one(%rip)
	fyl2x
	fstps	-12(%rsp)
	movss	-12(%rsp),%xmm0
	ret

2:	fyl2xp1
	fstps	-12(%rsp)
	movss	-12(%rsp),%xmm0
	ret

3:	jp	4b		// in case x is ±Inf
	fstp	%st(1)
	fstp	%st(1)
	fstps	-12(%rsp)
	movss	-12(%rsp),%xmm0
	ret
#else
	fldln2
	flds	4(%esp)
	fxam
	fnstsw
	fld	%st
	sahf
	jc	3f		// in case x is NaN or ±Inf

4:	fabs
	fcomps	limit
	fnstsw
	sahf
	jc	2f
	fadds	one
	fyl2x
	ret

2:	fyl2xp1
	ret

3:	jp	4b		// in case x is ±Inf
	fstp	%st(1)
	fstp	%st(1)
	ret
#endif
