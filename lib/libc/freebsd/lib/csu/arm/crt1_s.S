/* LINTLIBRARY */
/*-
 * SPDX-License-Identifier: BSD-4-Clause
 *
 * Copyright 2001 David E. O'Brien.
 * All rights reserved.
 * Copyright 1996-1998 John D. Polstra.
 * All rights reserved.
 * Copyright (c) 1997 Jason R. Thorpe.
 * Copyright (c) 1995 Christopher G. Demetriou
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *          This product includes software developed for the
 *          FreeBSD Project.  See https://www.freebsd.org/ for
 *          information about FreeBSD.
 *          This product includes software developed for the
 *          NetBSD Project.  See http://www.netbsd.org/ for
 *          information about NetBSD.
 * 4. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission
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
#include <sys/param.h>
#include <sys/elf_common.h>
#include "notes.h"

ENTRY(_start)
	mov	r5, r2		/* cleanup */
	mov	r4, r1		/* obj_main */
	mov	r3, r0		/* ps_strings */
	/* Get argc, argv, and envp from stack */
	ldr	r0, [sp, #0x0000]
	add	r1, sp, #0x0004
	add	r2, r1, r0, lsl #2
	add	r2, r2, #0x0004
	/* Ensure the stack is properly aligned before calling C code. */
	bic	sp, sp, #7
	sub	sp, sp, #8
	str	r5, [sp, #4]
	str	r4, [sp, #0]

	b	 __start
END(_start)

	.section .note.tag,"a",%note
	.p2align	2
	.4byte		2f-1f
	.4byte		4f-3f
	.4byte		NT_FREEBSD_ARCH_TAG
1:	.asciz		NOTE_FREEBSD_VENDOR
2:	.p2align	2
3:	.asciz		MACHINE_ARCH
4:

	.section .note.GNU-stack,"",%progbits
