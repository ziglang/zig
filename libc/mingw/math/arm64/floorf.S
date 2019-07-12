/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
 #include <_mingw_mac.h>

	.file	"floorf.S"
	.text
	.p2align 2
	.globl __MINGW_USYMBOL(floorf)
	.def	__MINGW_USYMBOL(floorf);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(floorf):
	frintm	s0, s0
	ret
