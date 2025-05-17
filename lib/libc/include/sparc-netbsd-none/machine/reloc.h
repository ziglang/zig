/*	$NetBSD: reloc.h,v 1.7 2005/12/11 12:19:06 christos Exp $ */

/*
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This software was developed by the Computer Systems Engineering group
 * at Lawrence Berkeley Laboratory under DARPA contract BG 91-66 and
 * contributed to Berkeley.
 *
 * All advertising materials mentioning features or use of this software
 * must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Lawrence Berkeley Laboratory.
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
 *	@(#)reloc.h	8.1 (Berkeley) 6/11/93
 */

/*
 * SPARC relocations.  The linker has, unfortunately, a large number
 * of link types.
 */
enum reloc_type {
		/* architecturally-required types */
	RELOC_8,		/*  8-bit absolute */
	RELOC_16,		/* 16-bit absolute */
	RELOC_32,		/* 32-bit absolute */
	RELOC_DISP8,		/*  8-bit pc-relative */
	RELOC_DISP16,		/* 16-bit pc-relative */
	RELOC_DISP32,		/* 32-bit pc-relative */
	RELOC_WDISP30,		/* 30-bit pc-relative signed word */
	RELOC_WDISP22,		/* 22-bit pc-relative signed word */
	RELOC_HI22,		/* 22-bit `%hi' (ie, sethi %hi(X),%l0) */
	RELOC_22,		/* 22-bit non-%hi (i.e., sethi X,%l0) */
	RELOC_13,		/* 13-bit absolute */
	RELOC_LO10,		/* 10-bit `%lo' */

		/* gnu ld understands some of these, but I do not */
	RELOC_SFA_BASE,		/* ? */
	RELOC_SFA_OFF13,	/* ? */
	RELOC_BASE10,		/* ? */
	RELOC_BASE13,		/* ? */
	RELOC_BASE22,		/* ? */

		/* gnu ld does not use these but Sun linker does */
		/* we define them anyway (note that they are included
		   in the freely-available gas sources!) */
		/* actually, newer gnu ld does generate some of these. */
	RELOC_PC10,		/* ? */
	RELOC_PC22,		/* ? */
	RELOC_JMP_TBL,		/* ? */
	RELOC_SEGOFF16,		/* ? */
	RELOC_GLOB_DAT,		/* ? */
	RELOC_JMP_SLOT,		/* ? */
	RELOC_RELATIVE,		/* ? */
	RELOC_UA_32,		/* unaligned 32bit relocation */

		/* The following are LP64 relocations */

	RELOC_PLT32,
	RELOC_HIPLT22,
	RELOC_LOPLT10,
	RELOC_PCPLT32,
	RELOC_PCPLT22,
	RELOC_PCPLT10,

	RELOC_10,
	RELOC_11,
	RELOC_64,
	RELOC_OLO10,
	RELOC_HH22,

	RELOC_HM10,
	RELOC_LM22,
	RELOC_PC_HH22,
	RELOC_PC_HM10,
	RELOC_PC_LM22,

	RELOC_WDISP16,
	RELOC_WDISP19,
	RELOC_GLOB_JMP,
	RELOC_7,
	RELOC_5,
	RELOC_6
};

/*
 * SPARC relocation info.
 *
 * Symbol-relative relocation is done by:
 *	1. locating the appropriate symbol
 *	2. if defined, adding (value + r_addend), subtracting pc if pc-rel,
 *	   and then shifting down 2 or 10 or 13 if necessary.
 * The resulting value is then to be stuffed into the appropriate bits
 * in the object (the low 22, or the high 30, or ..., etc).
 */
struct reloc_info_sparc {
	u_long	r_address;	/* relocation addr (offset in segment) */
	u_int	r_index:24,	/* segment (r_extern==0) or symbol index */
		r_extern:1,	/* if set, r_index is symbol index */
		:2;		/* unused */
	enum reloc_type r_type:5; /* relocation type, from above */
	long	r_addend;	/* value to add to symbol value */
};