/*	$NetBSD: psl.h,v 1.50.4.1 2023/08/09 17:42:02 martin Exp $ */

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
 *	@(#)psl.h	8.1 (Berkeley) 6/11/93
 */

#ifndef PSR_IMPL

/*
 * SPARC Process Status Register (in psl.h for hysterical raisins).  This
 * doesn't exist on the V9.
 *
 * The picture in the Sun manuals looks like this:
 *	                                     1 1
 *	 31   28 27   24 23   20 19       14 3 2 11    8 7 6 5 4       0
 *	+-------+-------+-------+-----------+-+-+-------+-+-+-+---------+
 *	|  impl |  ver  |  icc  |  reserved |E|E|  pil  |S|P|E|   CWP   |
 *	|       |       |n z v c|           |C|F|       | |S|T|         |
 *	+-------+-------+-------+-----------+-+-+-------+-+-+-+---------+
 */

#define PSR_IMPL	0xf0000000	/* implementation */
#define PSR_VER		0x0f000000	/* version */
#define PSR_ICC		0x00f00000	/* integer condition codes */
#define PSR_N		0x00800000	/* negative */
#define PSR_Z		0x00400000	/* zero */
#define PSR_O		0x00200000	/* overflow */
#define PSR_C		0x00100000	/* carry */
#define PSR_EC		0x00002000	/* coprocessor enable */
#define PSR_EF		0x00001000	/* FP enable */
#define PSR_PIL		0x00000f00	/* interrupt level */
#define PSR_S		0x00000080	/* supervisor (kernel) mode */
#define PSR_PS		0x00000040	/* previous supervisor mode (traps) */
#define PSR_ET		0x00000020	/* trap enable */
#define PSR_CWP		0x0000001f	/* current window pointer */

#define PSR_BITS "\20\16EC\15EF\10S\7PS\6ET"

/* 
 * SPARC V9 CCR register
 */

#define ICC_C	0x01L
#define ICC_V	0x02L
#define ICC_Z	0x04L
#define ICC_N	0x08L
#define XCC_SHIFT	4
#define XCC_C	(ICC_C<<XCC_SHIFT)
#define XCC_V	(ICC_V<<XCC_SHIFT)
#define XCC_Z	(ICC_Z<<XCC_SHIFT)
#define XCC_N	(ICC_N<<XCC_SHIFT)


/*
 * SPARC V9 PSTATE register (what replaces the PSR in V9)
 *
 * Here's the layout:
 *
 *    11   10    9     8   7  6   5     4     3     2     1   0
 *  +------------------------------------------------------------+
 *  | IG | MG | CLE | TLE | MM | RED | PEF | AM | PRIV | IE | AG |
 *  +------------------------------------------------------------+
 */

#define PSTATE_IG	0x800	/* enable spitfire interrupt globals */
#define PSTATE_MG	0x400	/* enable spitfire MMU globals */
#define PSTATE_CLE	0x200	/* current little endian */
#define PSTATE_TLE	0x100	/* traps little endian */
#define PSTATE_MM	0x0c0	/* memory model */
#define PSTATE_MM_TSO	0x000	/* total store order */
#define PSTATE_MM_PSO	0x040	/* partial store order */
#define PSTATE_MM_RMO	0x080	/* Relaxed memory order */
#define PSTATE_RED	0x020	/* RED state */
#define PSTATE_PEF	0x010	/* enable floating point */
#define PSTATE_AM	0x008	/* 32-bit address masking */
#define PSTATE_PRIV	0x004	/* privileged mode */
#define PSTATE_IE	0x002	/* interrupt enable */
#define PSTATE_AG	0x001	/* enable alternate globals */

#define PSTATE_BITS "\20\14IG\13MG\12CLE\11TLE\10\7MM\6RED\5PEF\4AM\3PRIV\2IE\1AG"


/*
 * 32-bit code requires TSO or at best PSO since that's what's supported on
 * SPARC V8 and earlier machines.
 *
 * 64-bit code sets the memory model in the ELF header.
 *
 * We're running kernel code in TSO for the moment so we don't need to worry
 * about possible memory barrier bugs.
 */

#ifdef __arch64__
#define PSTATE_PROM	(PSTATE_MM_TSO|PSTATE_PRIV)
#define PSTATE_NUCLEUS	(PSTATE_MM_TSO|PSTATE_PRIV|PSTATE_AG)
#define PSTATE_KERN	(PSTATE_MM_TSO|PSTATE_PRIV)
#define PSTATE_INTR	(PSTATE_KERN|PSTATE_IE)
#define PSTATE_USER32	(PSTATE_MM_TSO|PSTATE_AM|PSTATE_IE)
#define PSTATE_USER	(PSTATE_MM_RMO|PSTATE_IE)
#else
#define PSTATE_PROM	(PSTATE_MM_TSO|PSTATE_PRIV)
#define PSTATE_NUCLEUS	(PSTATE_MM_TSO|PSTATE_AM|PSTATE_PRIV|PSTATE_AG)
#define PSTATE_KERN	(PSTATE_MM_TSO|PSTATE_AM|PSTATE_PRIV)
#define PSTATE_INTR	(PSTATE_KERN|PSTATE_IE)
#define PSTATE_USER32	(PSTATE_MM_TSO|PSTATE_AM|PSTATE_IE)
#define PSTATE_USER	(PSTATE_MM_TSO|PSTATE_AM|PSTATE_IE)
#endif


/*
 * SPARC V9 TSTATE register
 *
 *   39 32 31 24 23 20  19   8	7 5 4   0
 *  +-----+-----+-----+--------+---+-----+
 *  | CCR | ASI |  -  | PSTATE | - | CWP |
 *  +-----+-----+-----+--------+---+-----+
 */

#define TSTATE_CWP		0x01f
#define TSTATE_PSTATE		0xfff00
#define TSTATE_PSTATE_SHIFT	8
#define TSTATE_ASI		0xff000000LL
#define TSTATE_ASI_SHIFT	24
#define TSTATE_CCR		0xff00000000LL
#define TSTATE_CCR_SHIFT	32

#define PSRCC_TO_TSTATE(x)	(((int64_t)(x)&PSR_ICC)<<(TSTATE_CCR_SHIFT-20))
#define TSTATECCR_TO_PSR(x)	(((x)&TSTATE_CCR)>>(TSTATE_CCR_SHIFT-20))

/*
 * These are here to simplify life.
 */
#define TSTATE_IG	(PSTATE_IG<<TSTATE_PSTATE_SHIFT)
#define TSTATE_MG	(PSTATE_MG<<TSTATE_PSTATE_SHIFT)
#define TSTATE_CLE	(PSTATE_CLE<<TSTATE_PSTATE_SHIFT)
#define TSTATE_TLE	(PSTATE_TLE<<TSTATE_PSTATE_SHIFT)
#define TSTATE_MM	(PSTATE_MM<<TSTATE_PSTATE_SHIFT)
#define TSTATE_MM_TSO	(PSTATE_MM_TSO<<TSTATE_PSTATE_SHIFT)
#define TSTATE_MM_PSO	(PSTATE_MM_PSO<<TSTATE_PSTATE_SHIFT)
#define TSTATE_MM_RMO	(PSTATE_MM_RMO<<TSTATE_PSTATE_SHIFT)
#define TSTATE_RED	(PSTATE_RED<<TSTATE_PSTATE_SHIFT)
#define TSTATE_PEF	(PSTATE_PEF<<TSTATE_PSTATE_SHIFT)
#define TSTATE_AM	(PSTATE_AM<<TSTATE_PSTATE_SHIFT)
#define TSTATE_PRIV	(PSTATE_PRIV<<TSTATE_PSTATE_SHIFT)
#define TSTATE_IE	(PSTATE_IE<<TSTATE_PSTATE_SHIFT)
#define TSTATE_AG	(PSTATE_AG<<TSTATE_PSTATE_SHIFT)

#define TSTATE_BITS "\20\14IG\13MG\12CLE\11TLE\10\7MM\6RED\5PEF\4AM\3PRIV\2IE\1AG"

#define TSTATE_KERN	((PSTATE_KERN)<<TSTATE_PSTATE_SHIFT)
#define TSTATE_USER	((PSTATE_USER)<<TSTATE_PSTATE_SHIFT)
/*
 * SPARC V9 VER version register.
 *
 *  63   48 47  32 31  24 23 16 15    8 7 5 4      0
 * +-------+------+------+-----+-------+---+--------+
 * | manuf | impl | mask |  -  | maxtl | - | maxwin |
 * +-------+------+------+-----+-------+---+--------+
 *
 */

#define VER_MANUF	0xffff000000000000LL
#define VER_MANUF_SHIFT	48
#define VER_IMPL	0x0000ffff00000000LL
#define VER_IMPL_SHIFT	32
#define VER_MASK	0x00000000ff000000LL
#define VER_MASK_SHIFT	24
#define VER_MAXTL	0x000000000000ff00LL
#define VER_MAXTL_SHIFT	8
#define VER_MAXWIN	0x000000000000001fLL

/*
 * Here are a few things to help us transition between user and kernel mode:
 */

/* Memory models */
#define KERN_MM		PSTATE_MM_TSO
#define USER_MM		PSTATE_MM_RMO

/* 
 * Register window handlers.  These point to generic routines that check the
 * stack pointer and then vector to the real handler.  We could optimize this
 * if we could guarantee only 32-bit or 64-bit stacks.
 */
#define WSTATE_KERN	026
#define WSTATE_USER	022

#define CWP		0x01f

/* 64-byte alignment -- this seems the best place to put this. */
#define SPARC64_BLOCK_SIZE	64
#define SPARC64_BLOCK_ALIGN	0x3f

#if (defined(_KERNEL) || defined(_KMEMUSER)) && !defined(_LOCORE)
typedef uint8_t ipl_t;
typedef struct {
	ipl_t _ipl;
} ipl_cookie_t;
#endif	/* _KERNEL|_KMEMUSER & !_LOCORE */

#if defined(_KERNEL) && !defined(_LOCORE)

/*
 * GCC pseudo-functions for manipulating PSR (primarily PIL field).
 */
static __inline __attribute__((__always_inline__)) int
getpsr(void)
{
	int psr;

	__asm volatile("rd %%psr,%0" : "=r" (psr));
	return (psr);
}

static __inline __attribute__((__always_inline__)) int
getmid(void)
{
	int mid;

	__asm volatile("rd %%tbr,%0" : "=r" (mid));
	return ((mid >> 20) & 0x3);
}

static __inline __attribute__((__always_inline__)) void
setpsr(int newpsr)
{
	__asm volatile("wr %0,0,%%psr" : : "r" (newpsr) : "memory");
	__asm volatile("nop; nop; nop");
}

static __inline __attribute__((__always_inline__)) void
spl0(void)
{
	int psr, oldipl;

	/*
	 * wrpsr xors two values: we choose old psr and old ipl here,
	 * which gives us the same value as the old psr but with all
	 * the old PIL bits turned off.
	 */
	__asm volatile("rd %%psr,%0" : "=r" (psr) : : "memory");
	oldipl = psr & PSR_PIL;
	__asm volatile("wr %0,%1,%%psr" : : "r" (psr), "r" (oldipl));

	/*
	 * Three instructions must execute before we can depend
	 * on the bits to be changed.
	 */
	__asm volatile("nop; nop; nop");
}

/*
 * PIL 1 through 14 can use this macro.
 * (spl0 and splhigh are special since they put all 0s or all 1s
 * into the ipl field.)
 */
#define	_SPLSET(name, newipl) \
static __inline __attribute__((__always_inline__)) void name(void) \
{ \
	int psr; \
	__asm volatile("rd %%psr,%0" : "=r" (psr)); \
	psr &= ~PSR_PIL; \
	__asm volatile("wr %0,%1,%%psr" : : \
	    "r" (psr), "n" ((newipl) << 8)); \
	__asm volatile("nop; nop; nop" : : : "memory"); \
}

_SPLSET(spllowerschedclock, IPL_SCHED)

static inline __always_inline ipl_cookie_t
makeiplcookie(ipl_t ipl)
{

	return (ipl_cookie_t){._ipl = ipl};
}

/* Raise IPL and return previous value */
static __inline __always_inline int
splraiseipl(ipl_cookie_t icookie)
{
	int newipl = icookie._ipl;
	int psr, oldipl;

	__asm volatile("rd %%psr,%0" : "=r" (psr));

	oldipl = psr & PSR_PIL;
	newipl <<= 8;
	if (newipl <= oldipl)
		return (oldipl);

	psr = (psr & ~oldipl) | newipl;

	__asm volatile("wr %0,0,%%psr" : : "r" (psr));
	__asm volatile("nop; nop; nop" : : : "memory");

	return (oldipl);
}

#include <sys/spl.h>

#define	splausoft()	splraiseipl(makeiplcookie(IPL_SOFTAUDIO))
#define	splfdsoft()	splraiseipl(makeiplcookie(IPL_SOFTFDC))

#define	splfd()		splraiseipl(makeiplcookie(IPL_FD))
#define	splts102()	splraiseipl(makeiplcookie(IPL_TS102))

#define	splzs()		splraiseipl(makeiplcookie(IPL_ZS))

/* splx does not have a return value */
static __inline __attribute__((__always_inline__)) void
splx(int newipl)
{
	int psr;

	__asm volatile("rd %%psr,%0" : "=r" (psr) : : "memory");
	__asm volatile("wr %0,%1,%%psr" : : \
	    "r" (psr & ~PSR_PIL), "rn" (newipl));
	__asm volatile("nop; nop; nop");
}
#endif /* KERNEL && !_LOCORE */

#endif /* PSR_IMPL */