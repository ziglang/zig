/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"nearbyintf.S"
	.text
	.align 2
	.globl __MINGW_USYMBOL(nearbyintf)
	.def	__MINGW_USYMBOL(nearbyintf);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(nearbyintf):
	mrs	x1, fpcr
	frintx	s0, s0
	msr	fpcr, x1
	ret
