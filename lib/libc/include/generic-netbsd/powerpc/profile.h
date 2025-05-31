/*	$NetBSD: profile.h,v 1.10 2021/11/02 11:22:03 ryo Exp $	*/

/*-
 * Copyright (c) 2000 Tsubai Masanari.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifdef _KERNEL_OPT
#include "opt_ppcarch.h"
#endif

#define	_MCOUNT_DECL	void __mcount

#ifdef _LP64

#define MCOUNT				\
__asm("	.globl	_mcount			\n" \
"	.section \".opd\",\"aw\"	\n" \
"	.align 3			\n" \
"_mcount:				\n" \
"	.quad	._mcount,.TOC.@tocbase,0\n" \
"	.previous			\n" \
"	.size	_mcount,24		\n" \
"	.type	._mcount,@function	\n" \
"	.globl	._mcount		\n" \
"	.align	3			\n" \
"._mcount:				\n" \
"	frame=128			\n" \
"	stdu	1,-frame(1)		\n" \
"	std	2,120(1)		\n" \
"	std	3,48+0(1)		\n" \
"	std	4,48+8(1)		\n" \
"	std	5,48+16(1)		\n" \
"	std	6,48+24(1)		\n" \
"	std	7,48+32(1)		\n" \
"	std	8,48+40(1)		\n" \
"	std	9,48+48(1)		\n" \
"	std	10,48+56(1)		\n" \
"					\n" \
"	mflr	4			\n" \
"	std	4,112(1)		\n" \
"	ld	3,frame+16(1)		\n" \
"	bl	.__mcount		\n" \
"	ld	2,120(1)		\n" \
"	ld	3,frame+16(1)		\n" \
"	mtlr	3			\n" \
"	ld	4,112(1)		\n" \
"	mtctr	4			\n" \
"					\n" \
"	ld	3,16(1)			\n" \
"	ld	4,20(1)			\n" \
"	ld	5,24(1)			\n" \
"	ld	6,28(1)			\n" \
"	ld	7,32(1)			\n" \
"	ld	8,36(1)			\n" \
"	ld	9,40(1)			\n" \
"	ld	10,44(1)		\n" \
"	addi	1,1,frame		\n" \
"	bctr");

#else

#ifdef __PIC__
#define _PLT "@plt"
#else
#define _PLT
#endif

#define MCOUNT				\
__asm("	.globl	_mcount			\n" \
"	.type	_mcount,@function	\n" \
"_mcount:				\n" \
"	stwu	1,-64(1)		\n" \
"	stw	3,16(1)			\n" \
"	stw	4,20(1)			\n" \
"	stw	5,24(1)			\n" \
"	stw	6,28(1)			\n" \
"	stw	7,32(1)			\n" \
"	stw	8,36(1)			\n" \
"	stw	9,40(1)			\n" \
"	stw	10,44(1)		\n" \
"					\n" \
"	mflr	4			\n" \
"	stw	4,48(1)			\n" \
"	lwz	3,68(1)			\n" \
"	bl	__mcount" _PLT "	\n" \
"	lwz	3,68(1)			\n" \
"	mtlr	3			\n" \
"	lwz	4,48(1)			\n" \
"	mtctr	4			\n" \
"					\n" \
"	lwz	3,16(1)			\n" \
"	lwz	4,20(1)			\n" \
"	lwz	5,24(1)			\n" \
"	lwz	6,28(1)			\n" \
"	lwz	7,32(1)			\n" \
"	lwz	8,36(1)			\n" \
"	lwz	9,40(1)			\n" \
"	lwz	10,44(1)		\n" \
"	addi	1,1,64			\n" \
"	bctr				\n" \
"_mcount_end:				\n" \
"	.size	_mcount,_mcount_end-_mcount");

#endif

#ifdef _KERNEL
#ifdef PPC_BOOKE
#include <powerpc/booke/cpuvar.h>

#define MCOUNT_ENTER	do s = wrtee(0); while (/*CONSTCOND*/ 0)
#define MCOUNT_EXIT	wrtee(s)
#else
#include <powerpc/psl.h>
#define MCOUNT_ENTER						\
	__asm volatile("mfmsr %0" : "=r"(s));			\
	if ((s & (PSL_IR | PSL_DR)) != (PSL_IR | PSL_DR))	\
		return;		/* XXX */			\
	s &= ~PSL_POW;						\
	__asm volatile("mtmsr %0" :: "r"(s & ~PSL_EE))

#define MCOUNT_EXIT						\
	__asm volatile("mtmsr %0" :: "r"(s))
#endif

#endif