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
	push	{r4, lr}
	vmrs	r4, fpscr
	bl	rintf
	vmsr	fpscr, r4
	pop	{r4, pc}
