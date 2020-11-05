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
	push {r4, r5, r11, lr}
	add r11, sp, #8
	vpush {d8}

	mov r4, r0
	mov r5, r1
	vmov.f64 d8, d0
	bl sin
	vstr d0, [r4]

	vmov.f64 d0, d8
	bl cos
	vstr d0, [r5]

	vpop {d8}
	pop {r4, r5, r11, pc}
