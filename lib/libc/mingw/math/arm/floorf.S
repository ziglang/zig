/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
 #include <_mingw_mac.h>

	.file	"floorf.S"
	.text
	.p2align 4,,15
	.globl __MINGW_USYMBOL(floorf)
	.def	__MINGW_USYMBOL(floorf);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(floorf):
	vmov	r2, s0
	lsr		r2, r2, #23
	bic		r2, r2, #0x100
	cmp		r2, #0xff /* Check for INF/NAN, just return the input in those cases */
	it		eq
	bxeq	lr
	vmrs	r1, fpscr
	bic		r0, r1, #0x00c00000
	orr		r0, r0, #0x00800000 /* Round towards Minus Infinity */
	vmsr	fpscr, r0
	vcvtr.s32.f32	s0, s0
	vcvt.f32.s32	s0, s0
	vmsr	fpscr, r1
	bx	lr
