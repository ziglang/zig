/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file "trunc.S"
	.text
	.p2align 4,,15
	.globl __MINGW_USYMBOL(trunc)
        .def    __MINGW_USYMBOL(trunc);  .scl    2;      .type   32;     .endef

__MINGW_USYMBOL(trunc):
	vmov	r2, r3, d0
	lsr		r3, r3, #20
	bic		r3, r3, #0x800
	movw	r2, #0x7ff
	cmp		r2, r3 /* Check for INF/NAN, just return the input in those cases */
	it		eq
	bxeq	lr
	vmrs	r1, fpscr
	orr		r0, r1, #0x00c00000 /* Round towards Zero */
	vmsr	fpscr, r0
	vcvtr.s32.f64	s0, d0
	vcvt.f64.s32	d0, s0
	vmsr	fpscr, r1
	bx	lr
