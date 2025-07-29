/*	$NetBSD: elf_support.h,v 1.1 2018/03/29 13:23:39 joerg Exp $	*/

/*-
 * Copyright (c) 2018 The NetBSD Foundation, Inc.
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
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
#ifndef _SPARC_ELF_SUPPORT_H
#define _SPARC_ELF_SUPPORT_H

static inline void
sparc_write_branch(void *where_, void *target)
{
	const unsigned int BAA     = 0x30800000U; /* ba,a  (offset / 4) */
	const unsigned int SETHI   = 0x03000000U; /* sethi %hi(0), %g1 */
	const unsigned int JMP     = 0x81c06000U; /* jmpl  %g1+%lo(0), %g0 */

	unsigned int *where = (unsigned int *)where_;
	unsigned long value = (unsigned long)target;
	unsigned long offset = value - (unsigned long)where;

#define	HIVAL(v, s)	(((v) >> (s)) & 0x003fffffU)
#define	LOVAL(v, s)	(((v) >> (s)) & 0x000003ffU)
	if (offset + 0x800000 <= 0x7ffffc) {
		/* Displacement is within 8MB, use a direct branch. */
		where[0] = BAA | ((offset >> 2) & 0x3fffff);
		__asm volatile("iflush %0+0" : : "r" (where));
		return;
	}

	/*
	 * The absolute address is a 32bit value.
	 * This can be encoded as:
	 *	sethi	%hi(value), %g1
	 *	jmp	%g1+%lo(value)
	 */
	where[1] = JMP   | LOVAL(value, 0);
	__asm volatile("iflush %0+4" : : "r" (where));
	where[0] = SETHI | HIVAL(value, 10);
	__asm volatile("iflush %0+0" : : "r" (where));
#undef	HIVAL
#undef	LOVAL
}
#endif