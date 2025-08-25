/*	$NetBSD: mcontext.h,v 1.18 2019/12/27 00:32:17 kamil Exp $	*/

/*-
 * Copyright (c) 2001 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Klaus Klein.
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

#ifndef _SPARC_MCONTEXT_H_
#define	_SPARC_MCONTEXT_H_

#define	_UC_SETSTACK	0x00010000
#define	_UC_CLRSTACK	0x00020000
#define	_UC_TLSBASE	0x00080000

/*
 * Layout of mcontext_t according the System V Application Binary Interface,
 * Edition 4.1, SPARC Processor ABI Supplement and updated for SPARC v9.
 */

#ifdef __arch64__
#define	_NGREG	21	/* %ccr, pc, npc, %g1-7, %o0-7, %asi, %fprs */
#else
#define	_NGREG	19	/* %psr, pc, npc, %g1-7, %o0-7 */
#endif
typedef	long int	__greg_t;
typedef	__greg_t	__gregset_t[_NGREG];

/* Offsets into gregset_t, for convenience. */
#define	_REG_CCR	0	/* 64 bit only */
#define	_REG_PSR	0	/* 32 bit only */
#define	_REG_PC		1
#define	_REG_nPC	2
#define	_REG_Y		3
#define	_REG_G1		4
#define	_REG_G2		5
#define	_REG_G3		6
#define	_REG_G4		7
#define	_REG_G5		8
#define	_REG_G6		9
#define	_REG_G7		10
#define	_REG_O0		11
#define	_REG_O1		12
#define	_REG_O2		13
#define	_REG_O3		14
#define	_REG_O4		15
#define	_REG_O5		16
#define	_REG_O6		17
#define	_REG_O7		18
#define	_REG_ASI	19	/* 64 bit only */
#define	_REG_FPRS	20	/* 64 bit only */


#define	_SPARC_MAXREGWINDOW	31

/* Layout of a register window. */
typedef struct {
	__greg_t	__rw_local[8];	/* %l0-7 */
	__greg_t	__rw_in[8];	/* %i0-7 */
} __rwindow_t;

/* Description of available register windows. */
typedef struct {
	int		__wbcnt;
	__greg_t *	__spbuf[_SPARC_MAXREGWINDOW];
	__rwindow_t	__wbuf[_SPARC_MAXREGWINDOW];
} __gwindows_t;

/* FPU address queue */
struct __fpq {
	unsigned int *	__fpq_addr;	/* address */
	unsigned int	__fpq_instr;	/* instruction */
};

struct __fq {
	union {
		double		__whole;
		struct __fpq	__fpq;
	} _FQu;
};

/* FPU state description */
typedef struct {
	union {
		unsigned int	__fpu_regs[32];
#ifdef __arch64__
		double		__fpu_dregs[32];
		long double	__fpu_qregs[16];
#else
		double		__fpu_dregs[16];
#endif
	} __fpu_fr;				/* FPR contents */
	struct __fq *	__fpu_q;		/* pointer to FPU insn queue */
	unsigned long	__fpu_fsr;		/* %fsr */
	unsigned char	__fpu_qcnt;		/* # entries in __fpu_q */
	unsigned char	__fpu_q_entrysize; 	/* size of a __fpu_q entry */
	unsigned char	__fpu_en;		/* this context valid? */
} __fpregset_t;

/* `Extra Register State'(?) */
typedef struct {
	unsigned int	__xrs_id;	/* See below */
	char *		__xrs_ptr;	/* points into filler area */
} __xrs_t;

#define	_XRS_ID		0x78727300	/* 'xrs\0' */

#ifdef __arch64__
/* Ancillary State Registers, 16-31 are available to user programs */
typedef	long		__asrset_t[16];	/* %asr16-31 */
#endif

typedef struct {
	__gregset_t	__gregs;	/* GPR state */
	__gwindows_t *	__gwins;	/* may point to register windows */
	__fpregset_t	__fpregs;	/* FPU state, if any */
	__xrs_t		__xrs;		/* may indicate extra reg state */
#ifdef __arch64__
	__asrset_t	__asrs;		/* ASR state */
#endif
} mcontext_t;

#ifdef __arch64__
#define	_UC_MACHINE_PAD	8		/* Padding appended to ucontext_t */
#define	_UC_MACHINE_SP(uc)	(((uc)->uc_mcontext.__gregs[_REG_O6]) + 0x7ff)
#define	_UC_MACHINE_FP(uc)	(((__greg_t *)_UC_MACHINE_SP(uc))[15])
#else
#define	_UC_MACHINE_PAD	43		/* Padding appended to ucontext_t */
#define	_UC_MACHINE_SP(uc)	((uc)->uc_mcontext.__gregs[_REG_O6])
#define	_UC_MACHINE_FP(uc)	(((__greg_t *)_UC_MACHINE_SP(uc))[15])
#endif
#define	_UC_MACHINE_PC(uc)	((uc)->uc_mcontext.__gregs[_REG_PC])
#define	_UC_MACHINE_INTRV(uc)	((uc)->uc_mcontext.__gregs[_REG_O0])

#define	_UC_MACHINE_SET_PC(uc, pc)					\
do {									\
	(uc)->uc_mcontext.__gregs[_REG_PC] = (pc);			\
	(uc)->uc_mcontext.__gregs[_REG_nPC] = (pc) + 4;			\
} while (/*CONSTCOND*/0)

#if defined(_RTLD_SOURCE) || defined(_LIBC_SOURCE) || \
    defined(__LIBPTHREAD_SOURCE__)
#include <sys/tls.h>

__BEGIN_DECLS
static __inline void *
__lwp_getprivate_fast(void)
{
	register void *__tmp;

	__asm volatile("mov %%g7, %0" : "=r" (__tmp));

	return __tmp;
}
__END_DECLS

#endif

#endif	/* !_SPARC_MCONTEXT_H_ */