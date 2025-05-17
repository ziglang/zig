/*	$NetBSD: elf_support.h,v 1.1 2018/03/29 13:23:40 joerg Exp $	*/

/*-
 * Copyright (c) 2000 Eduardo Horvath.
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
#ifndef _SPARC64_ELF_SUPPORT_H
#define _SPARC64_ELF_SUPPORT_H

#ifdef __arch64__
/*
 * Create a jump to the location `target` starting at `where`.
 * This requires up to 6 instructions.
 * The first instruction is written last as it replaces a branch
 * in the PLT during lazy binding.
 * The resulting code can trash %g1 and %g5.
 */
static inline void
sparc_write_branch(void *where_, void *target)
{
	const unsigned int BAA     = 0x30800000U; /* ba,a  (offset / 4) */
	const unsigned int SETHI   = 0x03000000U; /* sethi %hi(0), %g1 */
	const unsigned int JMP     = 0x81c06000U; /* jmpl  %g1+%lo(0), %g0 */
	const unsigned int OR      = 0x82106000U; /* or    %g1, 0, %g1 */
	const unsigned int XOR     = 0x82186000U; /* xor   %g1, 0, %g1 */
	const unsigned int MOV71   = 0x8213e000U; /* or    %o7, 0, %g1 */
	const unsigned int MOV17   = 0x9e106000U; /* or    %g1, 0, %o7 */
	const unsigned int CALL    = 0x40000000U; /* call  0 */
	const unsigned int SLLX    = 0x83287000U; /* sllx  %g1, 0, %g1 */
	const unsigned int NEG     = 0x82200001U; /* neg   %g1 */
	const unsigned int SETHIG5 = 0x0b000000U; /* sethi %hi(0), %g5 */
	const unsigned int ORG5    = 0x82104005U; /* or    %g1, %g5, %g1 */

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

	if (value <= 0xffffffffUL) {
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
		return;
	}

	if (value >= 0xffffffff00000000UL) {
		/*
		 * The top 32bit address range can be encoded as:
		 *	sethi	%hix(addr), %g1
		 *	xor	%g1, %lox(addr), %g1
		 *	jmp	%g1
		 */
		where[2] = JMP;
		where[1] = XOR | (value & 0x00003ff) | 0x1c00;
		__asm volatile("iflush %0+4" : : "r" (where));
		__asm volatile("iflush %0+8" : : "r" (where));
		where[0] = SETHI | HIVAL(~value, 10);
		__asm volatile("iflush %0+0" : : "r" (where));
		return;
	}

	if ((offset + 4) + 0x80000000UL <= 0x100000000UL) {
		/*
		 * Displacement of the second instruction is within
		 * +-2GB. This can use a direct call instruction:
		 *	mov	%o7, %g1
		 *	call	(value - .)
		 *	 mov	%g1, %o7
		 */
		where[1] = CALL | ((-(offset + 4)>> 2) & 0x3fffffffU);
		where[2] = MOV17;
		__asm volatile("iflush %0+4" : : "r" (where));
		__asm volatile("iflush %0+8" : : "r" (where));
		where[0] = MOV71;
		__asm volatile("iflush %0+0" : : "r" (where));
		return;
	}

	if (value < 0x100000000000UL) {
		/*
		 * The absolute address is a 44bit value.
		 * This can be encoded as:
		 *	sethi	%h44(addr), %g1
		 *	or	%g1, %m44(addr), %g1
		 *	sllx	%g1, 12, %g1
		 *	jmp	%g1+%l44(addr)
		 */
		where[1] = OR    | (((value) >> 12) & 0x00001fff);
		where[2] = SLLX  | 12;
		where[3] = JMP   | LOVAL(value, 0);
		__asm volatile("iflush %0+4" : : "r" (where));
		__asm volatile("iflush %0+8" : : "r" (where));
		__asm volatile("iflush %0+12" : : "r" (where));
		where[0] = SETHI | HIVAL(value, 22);
		__asm volatile("iflush %0+0" : : "r" (where));
		return;
	}

	if (value > 0xfffff00000000000UL) {
		/*
		 * The top 44bit address range can be encoded as:
		 *	sethi	%hi((-addr)>>12), %g1
		 *	or	%g1, %lo((-addr)>>12), %g1
		 *	neg	%g1
		 *	sllx	%g1, 12, %g1
		 *	jmp	%g1+(addr&0x0fff)
		 */
		unsigned long neg = (-value)>>12;
		where[1] = OR    | (LOVAL(neg, 0)+1);
		where[2] = NEG;
		where[3] = SLLX  | 12;
		where[4] = JMP   | (value & 0x0fff);
		__asm volatile("iflush %0+4" : : "r" (where));
		__asm volatile("iflush %0+8" : : "r" (where));
		__asm volatile("iflush %0+12" : : "r" (where));
		__asm volatile("iflush %0+16" : : "r" (where));
		where[0] = SETHI | HIVAL(neg, 10);
		__asm volatile("iflush %0+0" : : "r" (where));
		return;
	}

	/*
	 * The general case of a 64bit address is encoded as:
	 *	sethi	%hh(addr), %g1
	 *	sethi	%lm(addr), %g5
	 *	or	%g1, %hm(addr), %g1
	 *	sllx	%g1, 32, %g1
	 *	or	%g1, %g5, %g1
	 *	jmp	%g1+%lo(addr)
	 */
	where[1] = SETHIG5 | HIVAL(value, 10);
	where[2] = OR      | LOVAL(value, 32);
	where[3] = SLLX    | 32;
	where[4] = ORG5;
	where[5] = JMP     | LOVAL(value, 0);
	__asm volatile("iflush %0+4" : : "r" (where));
	__asm volatile("iflush %0+8" : : "r" (where));
	__asm volatile("iflush %0+12" : : "r" (where));
	__asm volatile("iflush %0+16" : : "r" (where));
	__asm volatile("iflush %0+20" : : "r" (where));
	where[0] = SETHI   | HIVAL(value, 42);
	__asm volatile("iflush %0+0" : : "r" (where));
#undef	HIVAL
#undef	LOVAL
}
#else
#include <sparc/elf_support.h>
#endif
#endif