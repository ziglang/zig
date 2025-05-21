/*	$NetBSD: asm.h,v 1.22 2021/04/17 20:12:55 rillig Exp $	*/

/*-
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
 *	@(#)asm.h	5.5 (Berkeley) 5/7/91
 */

#ifndef _AMD64_ASM_H_
#define _AMD64_ASM_H_

#ifdef __x86_64__

#ifdef __PIC__
#define PIC_PLT(x)	x@PLT
#define PIC_GOT(x)	x@GOTPCREL(%rip)
#else
#define PIC_PLT(x)	x
#define PIC_GOT(x)	x
#endif

#define _C_LABEL(x)	x
#define	_ASM_LABEL(x)	x

#define CVAROFF(x,y)		(_C_LABEL(x)+y)(%rip)

#ifdef __STDC__
# define __CONCAT(x,y)	x ## y
# define __STRING(x)	#x
#else
# define __CONCAT(x,y)	x/**/y
# define __STRING(x)	"x"
#endif

/* let kernels and others override entrypoint alignment */
#ifndef _ALIGN_TEXT
# ifdef _STANDALONE
#  define _ALIGN_TEXT .align 4
# else
#  define _ALIGN_TEXT .align 16
# endif
#endif

#define _ENTRY(x) \
	.text; _ALIGN_TEXT; .globl x; .type x,@function; x:
#define _LABEL(x) \
	.globl x; x:

#ifdef _KERNEL
/* XXX Can't use __CONCAT() here, as it would be evaluated incorrectly. */
#ifdef __STDC__
#define	IDTVEC(name) \
	ALIGN_TEXT; .globl X ## name; .type X ## name,@function; X ## name:
#define	IDTVEC_END(name) \
	.size X ## name, . - X ## name
#else
#define	IDTVEC(name) \
	ALIGN_TEXT; .globl X/**/name; .type X/**/name,@function; X/**/name:
#define	IDTVEC_END(name) \
	.size X/**/name, . - X/**/name
#endif /* __STDC__ */
#endif /* _KERNEL */

#ifdef __STDC__
#define CPUVAR(off)	%gs:CPU_INFO_ ## off
#else
#define CPUVAR(off)     %gs:CPU_INFO_/**/off
#endif


#ifdef GPROF
# define _PROF_PROLOGUE	\
	pushq %rbp; leaq (%rsp),%rbp; call PIC_PLT(__mcount); popq %rbp
#else
# define _PROF_PROLOGUE
#endif

#define	ENTRY(y)	_ENTRY(_C_LABEL(y)); _PROF_PROLOGUE
#define	NENTRY(y)	_ENTRY(_C_LABEL(y))
#define	ALTENTRY(x)	NENTRY(x)
#define	ASENTRY(y)	_ENTRY(_ASM_LABEL(y)); _PROF_PROLOGUE
#define	LABEL(y)	_LABEL(_C_LABEL(y))
#define	END(y)		.size y, . - y

#define	ASMSTR		.asciz

#define RCSID(x)	.pushsection ".ident","MS",@progbits,1;		\
			.asciz x;					\
			.popsection

#define	WEAK_ALIAS(alias,sym)						\
	.weak alias;							\
	alias = sym

/*
 * STRONG_ALIAS: create a strong alias.
 */
#define STRONG_ALIAS(alias,sym)						\
	.globl alias;							\
	alias = sym

#ifdef __STDC__
#define	WARN_REFERENCES(sym,msg)					\
	.pushsection .gnu.warning. ## sym;				\
	.ascii msg;							\
	.popsection
#else
#define	WARN_REFERENCES(sym,msg)					\
	.pushsection .gnu.warning./**/sym;				\
	.ascii msg;							\
	.popsection
#endif /* __STDC__ */

#else	/*	__x86_64__	*/

#include <i386/asm.h>

#endif	/*	__x86_64__	*/

#endif /* !_AMD64_ASM_H_ */