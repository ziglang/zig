/*	$NetBSD: reloc.h,v 1.10 2020/07/26 08:08:41 simonb Exp $	*/

/*-
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)reloc.h	8.1 (Berkeley) 6/10/93
 *
 * from: Header: reloc.h,v 1.6 92/06/20 09:59:37 torek Exp
 */

#ifndef __MIPS_RELOC_H__
#define	__MIPS_RELOC_H__
/*
 * MIPS relocation types.
 */
enum reloc_type {
	MIPS_RELOC_32,		/* 32-bit absolute */
	MIPS_RELOC_JMP,		/* 26-bit absolute << 2 | high 4 bits of pc */
	MIPS_RELOC_WDISP16,	/* 16-bit signed pc-relative << 2 */
	MIPS_RELOC_HI16,	/* 16-bit absolute << 16 */
	MIPS_RELOC_HI16_S,	/* 16-bit absolute << 16 (+1 if needed) */
	MIPS_RELOC_LO16		/* 16-bit absolute */
};

/*
 * MIPS relocation info.
 *
 * Symbol-relative relocation is done by:
 *	1. start with the value r_addend,
 *	2. locate the appropriate symbol and if defined, add symbol value,
 *	3. if pc relative, subtract pc,
 *	4. if the reloc_type is MIPS_RELOC_HI16_S and the result bit 15 is set,
 *		add 0x00010000,
 *	5. shift down 2 or 16 if necessary.
 * The resulting value is then to be stuffed into the appropriate bits
 * in the object (the low 16, or the low 26 bits).
 */
struct reloc_info_mips {
	u_long	r_address;	/* relocation addr (offset in segment) */
	u_int	r_index:24,	/* segment (r_extern==0) or symbol index */
		r_extern:1,	/* if set, r_index is symbol index */
		:2;		/* unused */
	enum reloc_type r_type:5; /* relocation type, from above */
	long	r_addend;	/* value to add to symbol value */
};

#define	relocation_info reloc_info_mips
#endif /* __MIPS_RELOC_H__ */