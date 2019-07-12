/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"floor.S"
	.text
	.p2align 2
	.globl __MINGW_USYMBOL(floor)
	.def	__MINGW_USYMBOL(floor);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(floor):
	frintm	d0, d0
	ret
