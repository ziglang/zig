/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"exp2f.S"
	.text
	.align 2
	.globl __MINGW_USYMBOL(exp2f)
	.def	__MINGW_USYMBOL(exp2f);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(exp2f):
	vmov s1, s0
	vmov.f32 s0, #2.0
	b powf
