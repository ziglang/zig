/*	$NetBSD: profile.h,v 1.17 2017/05/31 11:09:22 martin Exp $ */

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
 *	@(#)profile.h	8.1 (Berkeley) 6/11/93
 */

#ifdef __ELF__
#define _MCOUNT_SYM "__mcount"
#define	_MCOUNT_ENTRY "_mcount"
#else
#define _MCOUNT_SYM "___mcount"
#define	_MCOUNT_ENTRY "mcount"
#endif

#ifdef __PIC__
/* Inline expansion of PICCY_SET() (see <machine/asm.h>). */
#ifdef __arch64__
#define MCOUNT \
	__asm(".global " _MCOUNT_ENTRY);\
	__asm(_MCOUNT_ENTRY ":");\
	__asm("add %o7, 8, %o1");\
	__asm("1: rd %pc, %o2");\
	__asm("add %o2," _MCOUNT_SYM "-1b, %o2");\
	__asm("jmpl %o2, %g0");\
	__asm("add %i7, 8, %o0");
#else
#define MCOUNT \
	__asm(".global " _MCOUNT_ENTRY);\
	__asm(_MCOUNT_ENTRY ":");\
	__asm("add %o7, 8, %o1");\
	__asm("mov %o7, %o3");\
	__asm("1: call 2f; nop; 2:");\
	__asm("add %o7," _MCOUNT_SYM "-1b, %o2");\
	__asm("mov %o3, %o7");\
	__asm("jmpl %o2, %g0");\
	__asm("add %i7, 8, %o0");
#endif
#else
#define MCOUNT \
	__asm(".global " _MCOUNT_ENTRY);\
	__asm(_MCOUNT_ENTRY ":");\
	__asm("add %i7, 8, %o0");\
	__asm("sethi %hi(" _MCOUNT_SYM "), %o2");\
	__asm("jmpl %o2 + %lo(" _MCOUNT_SYM "), %g0");\
	__asm("add %o7, 8, %o1");
#endif

#define	_MCOUNT_DECL	static void __mcount

#ifdef _KERNEL
/*
 * Block interrupts during mcount so that those interrupts can also be
 * counted (as soon as we get done with the current counting).  On the
 * SPARC, we just splhigh/splx as those do not recursively invoke mcount.
 */
#define	MCOUNT_ENTER	s = splhigh()
#define	MCOUNT_EXIT	splx(s)
#endif /* _KERNEL */