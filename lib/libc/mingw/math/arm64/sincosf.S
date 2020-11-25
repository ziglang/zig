/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"sincosf.S"
	.text
	.align 2
	.globl __MINGW_USYMBOL(sincosf)
	.def	__MINGW_USYMBOL(sincosf);	.scl	2;	.type	32;	.endef
__MINGW_USYMBOL(sincosf):
	str d8, [sp, #-32]!
	str x30, [sp, #8]
	stp x19, x20, [sp, #16]

	mov x19, x0
	mov x20, x1
	fmov s8, s0
	bl sinf
	str s0, [x19]

	fmov s0, s8
	bl cosf
	str s0, [x20]

	ldp x19, x20, [sp, #16]
	ldr x30, [sp, #8]
	ldr d8, [sp], #32
	ret
