/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"nearbyint.S"
	.text
	.align 4
	.globl __MINGW_USYMBOL(nearbyint)
	.def	__MINGW_USYMBOL(nearbyint);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(nearbyint):
	push	{r4, lr}
	vmrs	r4, fpscr
	bl	rint
	vmsr	fpscr, r4
	pop	{r4, pc}
