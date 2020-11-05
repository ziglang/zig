/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"exp2.S"
	.text
	.align 2
	.globl __MINGW_USYMBOL(exp2)
	.globl __MINGW_USYMBOL(exp2l)
	.def	__MINGW_USYMBOL(exp2);	.scl	2;	.type	32;	.endef
	.def	__MINGW_USYMBOL(exp2l);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(exp2):
__MINGW_USYMBOL(exp2l):
	vmov.f64 d1, d0
	vmov.f64 d0, #2.0
	b pow
