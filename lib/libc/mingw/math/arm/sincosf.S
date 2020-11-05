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
	push {r4, r5, r11, lr}
	add r11, sp, #8
	vpush {d8}

	mov r4, r0
	mov r5, r1
	vmov.f32 s16, s0
	bl sinf
	vstr s0, [r4]

	vmov.f32 s0, s16
	bl cosf
	vstr s0, [r5]

	vpop {d8}
	pop {r4, r5, r11, pc}
