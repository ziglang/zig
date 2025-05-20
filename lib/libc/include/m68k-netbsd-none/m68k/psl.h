/*	$NetBSD: psl.h,v 1.15 2012/07/27 05:36:11 matt Exp $	*/

/*
 * Copyright (c) 1982, 1986, 1993
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
 *	@(#)psl.h	8.1 (Berkeley) 6/10/93
 */

#ifndef PSL_C
/*
 * MC68000 program status word
 */

#define	PSL_C		0x0001		/* carry bit */
#define	PSL_V		0x0002		/* overflow bit */
#define	PSL_Z		0x0004		/* zero bit */
#define	PSL_N		0x0008		/* negative bit */
#define	PSL_X		0x0010		/* extend bit */
#define	PSL_ALLCC	0x001F		/* all cc bits - unlikely */
#define	PSL_IPL0	0x0000		/* interrupt priority level 0 */
#define	PSL_IPL1	0x0100		/* interrupt priority level 1 */
#define	PSL_IPL2	0x0200		/* interrupt priority level 2 */
#define	PSL_IPL3	0x0300		/* interrupt priority level 3 */
#define	PSL_IPL4	0x0400		/* interrupt priority level 4 */
#define	PSL_IPL5	0x0500		/* interrupt priority level 5 */
#define	PSL_IPL6	0x0600		/* interrupt priority level 6 */
#define	PSL_IPL7	0x0700		/* interrupt priority level 7 */
#define	PSL_M		0x1000		/* master (kernel) sp vs intr sp */
#define	PSL_S		0x2000		/* supervisor enable bit */
/*	PSL_T0		0x4000		   ??? T0 on 68020, 8000 is T1 */
#define	PSL_T		0x8000		/* trace enable bit */

#define	PSL_LOWIPL	(PSL_S)
#define	PSL_HIGHIPL	(PSL_S | PSL_IPL7)
#define PSL_IPL		(PSL_IPL7)
#define	PSL_USER	(0)

#define	PSL_MBZ		0xFFFF58E0	/* must be zero bits */

#define	PSL_USERSET	(0)
#define	PSL_USERCLR	(PSL_S | PSL_IPL7 | PSL_MBZ)

#define	USERMODE(ps)	(((ps) & PSL_S) == 0)

#if defined(_KERNEL) && !defined(_LOCORE)

#define	IPL_SAFEPRI	PSL_LOWIPL	/* for kern_sleepq.c */

/*
 * spl functions; platform-specific code must define spl0 and splx().
 */

static __inline int
_spl(int s)
{
	int sr;

	__asm volatile ("movew %%sr,%0; movew %1,%%sr" :
	    "=&d" (sr) : "di" (s) : "memory");

	return sr;
}

static __inline int
_splraise(int level)
{
	int sr;

	__asm volatile("movw %%sr,%0" : "=d" (sr));

	if ((u_int16_t)level >= PSL_HIGHIPL || (u_int16_t)level > (u_int16_t)sr)
		__asm volatile("movw %0,%%sr" :: "di" (level) : "memory");

	return sr;
}

/* spl0 may require checking for software interrupts */
#define	_spl0()		_spl(PSL_S|PSL_IPL0)
#define	spl1()		_spl(PSL_S|PSL_IPL1)
#define	spl2()		_spl(PSL_S|PSL_IPL2)
#define	spl3()		_spl(PSL_S|PSL_IPL3)
#define	spl4()		_spl(PSL_S|PSL_IPL4)
#define	spl5()		_spl(PSL_S|PSL_IPL5)
#define	spl6()		_spl(PSL_S|PSL_IPL6)
#define	spl7()		_spl(PSL_S|PSL_IPL7)

#define	splraise1()	_splraise(PSL_S|PSL_IPL1)
#define	splraise2()	_splraise(PSL_S|PSL_IPL2)
#define	splraise3()	_splraise(PSL_S|PSL_IPL3)
#define	splraise4()	_splraise(PSL_S|PSL_IPL4)
#define	splraise5()	_splraise(PSL_S|PSL_IPL5)
#define	splraise6()	_splraise(PSL_S|PSL_IPL6)
#define	splraise7()	_splraise(PSL_S|PSL_IPL7)

#endif /* _KERNEL && ! _LOCORE */
#endif