/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1990 The Regents of the University of California.
 * All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * William Jolitz.
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
 *	from: @(#)DEFS.h	5.1 (Berkeley) 4/23/90
 */

#ifndef _MACHINE_ASM_H_
#define	_MACHINE_ASM_H_

#include <sys/cdefs.h>

#ifdef PIC
#define	PIC_PROLOGUE	\
	pushl	%ebx;	\
	call	1f;	\
1:			\
	popl	%ebx;	\
	addl	$_GLOBAL_OFFSET_TABLE_+[.-1b],%ebx
#define	PIC_EPILOGUE	\
	popl	%ebx
#define	PIC_PLT(x)	x@PLT
#define	PIC_GOT(x)	x@GOT(%ebx)
#define	PIC_GOTOFF(x)	x@GOTOFF(%ebx)
#else
#define	PIC_PROLOGUE
#define	PIC_EPILOGUE
#define	PIC_PLT(x)	x
#define	PIC_GOTOFF(x)	x
#endif

/*
 * CNAME and HIDENAME manage the relationship between symbol names in C
 * and the equivalent assembly language names.  CNAME is given a name as
 * it would be used in a C program.  It expands to the equivalent assembly
 * language name.  HIDENAME is given an assembly-language name, and expands
 * to a possibly-modified form that will be invisible to C programs.
 */
#define CNAME(csym)		csym
#define HIDENAME(asmsym)	.asmsym

/* XXX should use .p2align 4,0x90 for -m486. */
#define _START_ENTRY	.text; .p2align 2,0x90

#define _ENTRY(x)	_START_ENTRY; \
			.globl CNAME(x); .type CNAME(x),@function; CNAME(x): \
			.cfi_startproc
#define	END(x)		.cfi_endproc; .size x, . - x

#ifdef PROF
#define	ALTENTRY(x)	_ENTRY(x); \
			pushl %ebp; \
			.cfi_def_cfa_offset 8; \
			.cfi_offset %ebp, -8; \
			movl %esp,%ebp; \
			call PIC_PLT(HIDENAME(mcount)); \
			popl %ebp; \
			.cfi_restore %ebp; \
			.cfi_def_cfa_offset 4; \
			jmp 9f
#define	ENTRY(x)	_ENTRY(x); \
			pushl %ebp; \
			.cfi_def_cfa_offset 8; \
			.cfi_offset %ebp, -8; \
			movl %esp,%ebp; \
			call PIC_PLT(HIDENAME(mcount)); \
			popl %ebp; \
			.cfi_restore %ebp; \
			.cfi_def_cfa_offset 4; \
			9:
#else
#define	ALTENTRY(x)	_ENTRY(x)
#define	ENTRY(x)	_ENTRY(x)
#endif

/*
 * WEAK_REFERENCE(): create a weak reference alias from sym.
 * The macro is not a general asm macro that takes arbitrary names,
 * but one that takes only C names. It does the non-null name
 * translation inside the macro.
 */

#define	WEAK_REFERENCE(sym, alias)					\
	.weak CNAME(alias);						\
	.equ CNAME(alias),CNAME(sym)

/*
 * STRONG_ALIAS: create a strong alias.
 */
#define	STRONG_ALIAS(alias,sym)						\
	.globl alias;							\
	alias = sym

#define RCSID(x)	.text; .asciz x

#undef __FBSDID
#if !defined(STRIP_FBSDID)
#define __FBSDID(s)	.ident s
#else
#define __FBSDID(s)	/* nothing */
#endif /* not STRIP_FBSDID */

#endif /* !_MACHINE_ASM_H_ */