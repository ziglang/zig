/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"nearbyintl.S"
	.text
	.align 4
	.globl __MINGW_USYMBOL(nearbyintl)
	.def	__MINGW_USYMBOL(nearbyintl);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(nearbyintl):
	push	{r4, lr}
	vmrs	r4, fpscr
	bl	rintl
	vmsr	fpscr, r4
	pop	{r4, pc}
