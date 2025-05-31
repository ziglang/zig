/*	$NetBSD: psl.h,v 1.62.4.2 2023/09/09 15:01:24 martin Exp $ */

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

/* Interesting spl()s */
#define PIL_BIO		5
#define PIL_VIDEO	5
#define PIL_TTY		6
#define PIL_LPT		6
#define PIL_NET		6
#define PIL_VM		7
#define	PIL_AUD		8
#define PIL_CLOCK	10
#define PIL_FD		11
#define PIL_SER		12
#define	PIL_STATCLOCK	14
#define PIL_HIGH	15
#define PIL_SCHED	PIL_CLOCK
#define PIL_LOCK	PIL_HIGH

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

#define MANUF_FUJITSU		0x04 /* Fujitsu SPARC64 */
#define MANUF_SUN		0x17 /* Sun UltraSPARC */

#define IMPL_SPARC64		0x01 /* SPARC64 */
#define IMPL_SPARC64_II		0x02 /* SPARC64-II */
#define IMPL_SPARC64_III	0x03 /* SPARC64-III */
#define IMPL_SPARC64_IV		0x04 /* SPARC64-IV */
#define IMPL_ZEUS		0x05 /* SPARC64-V */
#define IMPL_OLYMPUS_C		0x06 /* SPARC64-VI */
#define IMPL_JUPITER		0x07 /* SPARC64-VII */

#define IMPL_SPITFIRE		0x10 /* UltraSPARC-I */
#define IMPL_BLACKBIRD		0x11 /* UltraSPARC-II */
#define IMPL_SABRE		0x12 /* UltraSPARC-IIi */
#define IMPL_HUMMINGBIRD	0x13 /* UltraSPARC-IIe */
#define IMPL_CHEETAH		0x14 /* UltraSPARC-III */
#define IMPL_CHEETAH_PLUS	0x15 /* UltraSPARC-III+ */
#define IMPL_JALAPENO		0x16 /* UltraSPARC-IIIi */
#define IMPL_JAGUAR		0x18 /* UltraSPARC-IV */
#define IMPL_PANTHER		0x19 /* UltraSPARC-IV+ */
#define IMPL_SERRANO		0x22 /* UltraSPARC-IIIi+ */

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

/*
 * UltraSPARC Ancillary State Registers
 */
#define SET_SOFTINT	%asr20	/* Set Software Interrupt register bits */
#define CLEAR_SOFTINT	%asr21	/* Clear Software Interrupt register bits */
#define SOFTINT		%asr22	/* Software Interrupt register */
#define TICK_CMPR	%asr23	/* TICK Compare register */
#define STICK		%asr24	/* STICK register */
#define STICK_CMPR	%asr25	/* STICK Compare register */

/* SOFTINT bit descriptions */
#define TICK_INT	0x01		/* CPU clock timer interrupt */
#define STICK_INT	(0x1<<16)	/* system clock timer interrupt */

/* 64-byte alignment -- this seems the best place to put this. */
#define SPARC64_BLOCK_SIZE	64
#define SPARC64_BLOCK_ALIGN	0x3f


#if (defined(_KERNEL) || defined(_KMEMUSER)) && !defined(_LOCORE)
typedef uint8_t ipl_t;
typedef struct {
	ipl_t _ipl;
} ipl_cookie_t;
#endif /* _KERNEL|_KMEMUSER&!_LOCORE */

#if defined(_KERNEL) && !defined(_LOCORE)

#if defined(_KERNEL_OPT)
#include "opt_sparc_arch.h"
#endif

/*
 * Put "memory" to asm inline on sun4v to avoid issuing rdpr %ver
 * before checking cputyp as a result of code moving by compiler
 * optimization.
 */
#ifdef SUN4V
#define constasm_clobbers "memory"
#else
#define constasm_clobbers
#endif

/*
 * Inlines for manipulating privileged and ancillary state registers
 */
#define SPARC64_RDCONST_DEF(rd, name, reg, type)			\
static __inline __constfunc type get##name(void)			\
{									\
	type _val;							\
	__asm(#rd " %" #reg ",%0" : "=r" (_val) : : constasm_clobbers);	\
	return _val;							\
}
#define SPARC64_RD_DEF(rd, name, reg, type)				\
static __inline type get##name(void)					\
{									\
	type _val;							\
	__asm volatile(#rd " %" #reg ",%0" : "=r" (_val));		\
	return _val;							\
}
#define SPARC64_WR_DEF(wr, name, reg, type)				\
static __inline void set##name(type _val)				\
{									\
	__asm volatile(#wr " %0,0,%" #reg : : "r" (_val) : "memory");	\
}

#ifdef __arch64__
#define SPARC64_RDCONST64_DEF(rd, name, reg) \
	SPARC64_RDCONST_DEF(rd, name, reg, uint64_t)
#define SPARC64_RD64_DEF(rd, name, reg) SPARC64_RD_DEF(rd, name, reg, uint64_t)
#define SPARC64_WR64_DEF(wr, name, reg) SPARC64_WR_DEF(wr, name, reg, uint64_t)
#else
#define SPARC64_RDCONST64_DEF(rd, name, reg)				\
static __inline __constfunc uint64_t get##name(void)			\
{									\
	uint32_t _hi, _lo;						\
	__asm(#rd " %" #reg ",%0; srl %0,0,%1; srlx %0,32,%0"		\
		: "=r" (_hi), "=r" (_lo) : : constasm_clobbers);	\
	return ((uint64_t)_hi << 32) | _lo;				\
}
#define SPARC64_RD64_DEF(rd, name, reg)					\
static __inline uint64_t get##name(void)				\
{									\
	uint32_t _hi, _lo;						\
	__asm volatile(#rd " %" #reg ",%0; srl %0,0,%1; srlx %0,32,%0"	\
		: "=r" (_hi), "=r" (_lo));				\
	return ((uint64_t)_hi << 32) | _lo;				\
}
#define SPARC64_WR64_DEF(wr, name, reg)					\
static __inline void set##name(uint64_t _val)				\
{									\
	uint32_t _hi = _val >> 32, _lo = _val;				\
	__asm volatile("sllx %1,32,%0; or %0,%2,%0; " #wr " %0,0,%" #reg\
		       : "=&r" (_hi) /* scratch register */		\
		       : "r" (_hi), "r" (_lo) : "memory");		\
}
#endif

#define SPARC64_RDPR_DEF(name, reg, type) SPARC64_RD_DEF(rdpr, name, reg, type)
#define SPARC64_WRPR_DEF(name, reg, type) SPARC64_WR_DEF(wrpr, name, reg, type)
#define SPARC64_RDPR64_DEF(name, reg)	SPARC64_RD64_DEF(rdpr, name, reg)
#define SPARC64_WRPR64_DEF(name, reg)	SPARC64_WR64_DEF(wrpr, name, reg)
#define SPARC64_RDASR64_DEF(name, reg)	SPARC64_RD64_DEF(rd, name, reg)
#define SPARC64_WRASR64_DEF(name, reg)	SPARC64_WR64_DEF(wr, name, reg)

/* Tick Register (PR 4) */
SPARC64_RDPR64_DEF(tick, %tick)			/* gettick() */
SPARC64_WRPR64_DEF(tick, %tick)			/* settick() */

/* Processor State Register (PR 6) */
SPARC64_RDPR_DEF(pstate, %pstate, int)		/* getpstate() */
SPARC64_WRPR_DEF(pstate, %pstate, int)		/* setpstate() */

/* Trap Level Register (PR 7) */
SPARC64_RDPR_DEF(tl, %tl, int)			/* gettl() */

/* Current Window Pointer Register (PR 9) */
SPARC64_RDPR_DEF(cwp, %cwp, int)		/* getcwp() */
SPARC64_WRPR_DEF(cwp, %cwp, int)		/* setcwp() */

/* Version Register (PR 31) */
SPARC64_RDCONST64_DEF(rdpr, ver, %ver)		/* getver() */

/* System Tick Register (ASR 24) */
SPARC64_RDASR64_DEF(stick, STICK)		/* getstick() */
SPARC64_WRASR64_DEF(stick, STICK)		/* setstick() */

/* System Tick Compare Register (ASR 25) */
SPARC64_RDASR64_DEF(stickcmpr, STICK_CMPR)	/* getstickcmpr() */

/* Some simple macros to check the cpu type. */
#define GETVER_CPU_MASK()	((getver() & VER_MASK) >> VER_MASK_SHIFT)
#define GETVER_CPU_IMPL()	((getver() & VER_IMPL) >> VER_IMPL_SHIFT)
#define GETVER_CPU_MANUF()	((getver() & VER_MANUF) >> VER_MANUF_SHIFT)
#define CPU_IS_SPITFIRE()	(GETVER_CPU_IMPL() == IMPL_SPITFIRE)
#define CPU_IS_HUMMINGBIRD()	(GETVER_CPU_IMPL() == IMPL_HUMMINGBIRD)
#define CPU_IS_USIIIi()		((GETVER_CPU_IMPL() == IMPL_JALAPENO) || \
				 (GETVER_CPU_IMPL() == IMPL_SERRANO))
#define CPU_IS_USIII_UP()	(GETVER_CPU_IMPL() >= IMPL_CHEETAH)
#define CPU_IS_SPARC64_V_UP()	(GETVER_CPU_MANUF() == MANUF_FUJITSU && \
				 GETVER_CPU_IMPL() >= IMPL_ZEUS)

static __inline int
intr_disable(void)
{
	int pstate = getpstate();

	setpstate(pstate & ~PSTATE_IE);
	return pstate;
}

static __inline void
intr_restore(int pstate)
{
	setpstate(pstate);
}

/*
 * GCC pseudo-functions for manipulating PIL
 */

#ifdef SPLDEBUG
void prom_printf(const char *fmt, ...);
extern int printspl;
#define SPLPRINT(x) \
{ \
	if (printspl) { \
		int i = 10000000; \
		prom_printf x ; \
		while (i--) \
			; \
	} \
}
#define	SPL(name, newpil) \
static __inline int name##X(const char* file, int line) \
{ \
	int oldpil; \
	__asm volatile("rdpr %%pil,%0" : "=r" (oldpil)); \
	SPLPRINT(("{%s:%d %d=>%d}", file, line, oldpil, newpil)); \
	__asm volatile("wrpr %%g0,%0,%%pil" : : "n" (newpil) : "memory"); \
	return (oldpil); \
}
/* A non-priority-decreasing version of SPL */
#define	SPLHOLD(name, newpil) \
static __inline int name##X(const char* file, int line) \
{ \
	int oldpil; \
	__asm volatile("rdpr %%pil,%0" : "=r" (oldpil)); \
	if (newpil <= oldpil) \
		return oldpil; \
	SPLPRINT(("{%s:%d %d->!d}", file, line, oldpil, newpil)); \
	__asm volatile("wrpr %%g0,%0,%%pil" : : "n" (newpil) : "memory"); \
	return (oldpil); \
}

#else
#define SPLPRINT(x)	
#define	SPL(name, newpil) \
static __inline __always_inline int name(void) \
{ \
	int oldpil; \
	__asm volatile("rdpr %%pil,%0" : "=r" (oldpil)); \
	__asm volatile("wrpr %%g0,%0,%%pil" : : "n" (newpil) : "memory"); \
	return (oldpil); \
}
/* A non-priority-decreasing version of SPL */
#define	SPLHOLD(name, newpil) \
static __inline __always_inline int name(void) \
{ \
	int oldpil; \
	__asm volatile("rdpr %%pil,%0" : "=r" (oldpil)); \
	if (newpil <= oldpil) \
		return oldpil; \
	__asm volatile("wrpr %%g0,%0,%%pil" : : "n" (newpil) : "memory"); \
	return (oldpil); \
}
#endif

static __inline ipl_cookie_t
makeiplcookie(ipl_t ipl)
{

	return (ipl_cookie_t){._ipl = ipl};
}

static __inline int __attribute__((__unused__))
splraiseipl(ipl_cookie_t icookie)
{
	int newpil = icookie._ipl;
	int oldpil;

	/*
	 * NetBSD/sparc64's IPL_* constants equate directly to the
	 * corresponding PIL_* names; no need to map them here.
	 */
	__asm volatile("rdpr %%pil,%0" : "=r" (oldpil));
	if (newpil <= oldpil)
		return (oldpil);
	__asm volatile("wrpr %0,0,%%pil" : : "r" (newpil) : "memory");
	return (oldpil);
}

SPL(spl0, 0)

SPLHOLD(splsoftint, 1)
#define	splsoftclock	splsoftint
#define	splsoftnet	splsoftint

SPLHOLD(splsoftserial, 4)

/*
 * Memory allocation (must be as high as highest network, tty, or disk device)
 */
SPLHOLD(splvm, PIL_VM)

SPLHOLD(splsched, PIL_SCHED)

SPLHOLD(splhigh, PIL_HIGH)

/* splx does not have a return value */
#ifdef SPLDEBUG
#define	spl0()	spl0X(__FILE__, __LINE__)
#define	splsoftint()	splsoftintX(__FILE__, __LINE__)
#define	splsoftserial()	splsoftserialX(__FILE__, __LINE__)
#define	splausoft()	splausoftX(__FILE__, __LINE__)
#define	splfdsoft()	splfdsoftX(__FILE__, __LINE__)
#define	splvm()		splvmX(__FILE__, __LINE__)
#define	splclock()	splclockX(__FILE__, __LINE__)
#define	splfd()		splfdX(__FILE__, __LINE__)
#define	splzs()		splzsX(__FILE__, __LINE__)
#define	splserial()	splzerialX(__FILE__, __LINE__)
#define	splaudio()	splaudioX(__FILE__, __LINE__)
#define	splstatclock()	splstatclockX(__FILE__, __LINE__)
#define	splsched()	splschedX(__FILE__, __LINE__)
#define	spllock()	spllockX(__FILE__, __LINE__)
#define	splhigh()	splhighX(__FILE__, __LINE__)
#define splx(x)		splxX((x),__FILE__, __LINE__)

static __inline void splxX(int newpil, const char *file, int line)
#else
static __inline __always_inline void splx(int newpil)
#endif
{
#ifdef SPLDEBUG
	int pil;

	__asm volatile("rdpr %%pil,%0" : "=r" (pil));
	SPLPRINT(("{%d->%d}", pil, newpil));
#endif
	__asm volatile("wrpr %%g0,%0,%%pil" : : "rn" (newpil) : "memory");
}
#endif /* KERNEL && !_LOCORE */

#endif /* PSR_IMPL */