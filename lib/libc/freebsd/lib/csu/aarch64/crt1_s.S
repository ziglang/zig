/* LINTLIBRARY */
/*-
 * Copyright 1996-1998 John D. Polstra.
 * Copyright 2014 Andrew Turner.
 * Copyright 2014-2015 The FreeBSD Foundation.
 * All rights reserved.
 *
 * Portions of this software were developed by Andrew Turner
 * under sponsorship from the FreeBSD Foundation.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <machine/asm.h>
#include <sys/elf_common.h>

	/*
	 * The program entry point
	 * void _start(char **ap, void (*cleanup)(void)) __dead2
	 */
ENTRY(_start)
	.cfi_undefined x30
	mov	x3, x2		/* cleanup */
	add	x1, x0, #8	/* load argv */
	ldr	x0, [x0]	/* load argc */
	add	x2, x1, x0, lsl #3 /* env is after argv */
	add	x2, x2, #8	/* argv is null terminated */
#ifdef PIC
	adrp	x4, :got:main
	ldr	x4, [x4, :got_lo12:main]
#else
	ldr	x4, =main
#endif
#ifdef GCRT
	ldr	x5, =eprol
	ldr	x6, =etext
	/*
	 * __libc_start1_gcrt(argc, argv, env, cleanup, main, &eprol, &etext)
	 */
	bl	__libc_start1_gcrt
eprol:
#else
	/* __libc_start1(argc, argv, env, cleanup, main) */
	bl	__libc_start1
#endif
END(_start)

	.section .note.GNU-stack,"",@progbits

GNU_PROPERTY_AARCH64_FEATURE_1_NOTE(GNU_PROPERTY_AARCH64_FEATURE_1_VAL)
