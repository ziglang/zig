/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"sincos.S"
	.text
	.align 2
	.globl __MINGW_USYMBOL(sincos)
	.globl __MINGW_USYMBOL(sincosl)
	.def	__MINGW_USYMBOL(sincos);	.scl	2;	.type	32;	.endef
	.def	__MINGW_USYMBOL(sincosl);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(sincos):
__MINGW_USYMBOL(sincosl):
	str d8, [sp, #-32]!
	str x30, [sp, #8]
	stp x19, x20, [sp, #16]

	mov x19, x0
	mov x20, x1
	fmov d8, d0
	bl sin
	str d0, [x19]

	fmov d0, d8
	bl cos
	str d0, [x20]

	ldp x19, x20, [sp, #16]
	ldr x30, [sp, #8]
	ldr d8, [sp], #32
	ret
