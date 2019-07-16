/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"nearbyintf.S"
	.text
	.align 4
	.globl __MINGW_USYMBOL(nearbyintf)
	.def	__MINGW_USYMBOL(nearbyintf);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(nearbyintf):
	vmov	r2, r3, d0
	lsr		r3, r3, #20
	bic		r3, r3, #0x800
	movw	r2, #0x7ff
	cmp		r2, r3 /* Check for INF/NAN, just return the input in those cases */
	it		eq
	bxeq	lr
	vmrs	r1, fpscr
	vcvtr.s32.f32	s0, s0
	vcvt.f32.s32	s0, s0
	vmsr	fpscr, r1
	bx	lr
