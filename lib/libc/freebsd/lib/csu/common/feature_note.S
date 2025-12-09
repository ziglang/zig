/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright 2000 David E. O'Brien, John D. Polstra.
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
#include "notes.h"

	.section .note.tag,"aR",%note
	.p2align	2
	.4byte		2f-1f
	.4byte		4f-3f
	.4byte		NT_FREEBSD_FEATURE_CTL
1:	.asciz		NOTE_FREEBSD_VENDOR
2:	.p2align	2
3:	.4byte		0
4:

	.section .note.GNU-stack,"",%progbits

#ifdef __aarch64__
/* This is needed in all objects for BTI to be used in the linked elf file */
GNU_PROPERTY_AARCH64_FEATURE_1_NOTE(GNU_PROPERTY_AARCH64_FEATURE_1_VAL)
#endif
