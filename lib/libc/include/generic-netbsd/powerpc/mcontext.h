/*	$NetBSD: mcontext.h,v 1.22 2020/10/04 10:34:18 rin Exp $	*/

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

#ifndef _POWERPC_MCONTEXT_H_
#define _POWERPC_MCONTEXT_H_

/*
 * Layout of mcontext_t based on the System V Application Binary Interface,
 * Edition 4.1, PowerPC Processor ABI Supplement - September 1995, and
 * extended for the AltiVec Register File.  Note that due to the increased
 * alignment requirements of the latter, the offset of mcontext_t within
 * an ucontext_t is different from System V.
 */

#define	_NGREG	39		/* GR0-31, CR, LR, SRR0, SRR1, CTR, XER, MQ */

typedef	long		__greg_t;
typedef	__greg_t	__gregset_t[_NGREG];

#define	_REG_R0		0
#define	_REG_R1		1
#define	_REG_R2		2
#define	_REG_R3		3
#define	_REG_R4		4
#define	_REG_R5		5
#define	_REG_R6		6
#define	_REG_R7		7
#define	_REG_R8		8
#define	_REG_R9		9
#define	_REG_R10	10
#define	_REG_R11	11
#define	_REG_R12	12
#define	_REG_R13	13
#define	_REG_R14	14
#define	_REG_R15	15
#define	_REG_R16	16
#define	_REG_R17	17
#define	_REG_R18	18
#define	_REG_R19	19
#define	_REG_R20	20
#define	_REG_R21	21
#define	_REG_R22	22
#define	_REG_R23	23
#define	_REG_R24	24
#define	_REG_R25	25
#define	_REG_R26	26
#define	_REG_R27	27
#define	_REG_R28	28
#define	_REG_R29	29
#define	_REG_R30	30
#define	_REG_R31	31
#define	_REG_CR		32		/* Condition Register */
#define	_REG_LR		33		/* Link Register */
#define	_REG_PC		34		/* PC (copy of SRR0) */
#define	_REG_MSR	35		/* MSR (copy of SRR1) */
#define	_REG_CTR	36		/* Count Register */
#define	_REG_XER	37		/* Integer Exception Register */
#define	_REG_MQ		38		/* MQ Register (POWER only) */

typedef struct {
#ifdef _KERNEL
	unsigned long long	__fpu_regs[32];	/* FP0-31 */
#else
	double		__fpu_regs[32];	/* FP0-31 */
#endif
	unsigned int	__fpu_fpscr;	/* FP Status and Control Register */
	unsigned int	__fpu_valid;	/* Set together with _UC_FPU */
} __fpregset_t;

#define	_NVR	32			/* Number of Vector registers */

typedef struct {
	union __vr {
		unsigned char	__vr8[16];
		unsigned short	__vr16[8];
		unsigned int	__vr32[4];
		unsigned char	__spe8[8];
		unsigned short	__spe16[4];
		unsigned int	__spe32[2];
	} 		__vrs[_NVR] __aligned(16);
	unsigned int	__vscr;		/* VSCR */
	unsigned int	__vrsave;	/* VRSAVE */
} __vrf_t;

typedef struct {
	__gregset_t	__gregs;	/* General Purpose Register set */
	__fpregset_t	__fpregs;	/* Floating Point Register set */
	__vrf_t		__vrf;		/* Vector Register File */
} mcontext_t;

#if defined(_LP64)
typedef	int		__greg32_t;
typedef	__greg32_t	__gregset32_t[_NGREG];

typedef struct {
	__gregset32_t	__gregs;	/* General Purpose Register set */
	__fpregset_t	__fpregs;	/* Floating Point Register set */
	__vrf_t		__vrf;		/* Vector Register File */
} mcontext32_t;
#endif

/* Machine-dependent uc_flags */
#define	_UC_POWERPC_VEC	0x00010000	/* Vector Register File valid */
#define	_UC_POWERPC_SPE	0x00020000	/* Vector Register File valid */
#define	_UC_TLSBASE	0x00080000	/* thread context valid in R2 */
#define	_UC_SETSTACK	0x00100000
#define	_UC_CLRSTACK	0x00200000

#define _UC_MACHINE_SP(uc)	((uc)->uc_mcontext.__gregs[_REG_R1])
#define _UC_MACHINE_FP(uc)	((uc)->uc_mcontext.__gregs[_REG_R31])
#define _UC_MACHINE_PC(uc)	((uc)->uc_mcontext.__gregs[_REG_PC])
#define _UC_MACHINE_INTRV(uc)	((uc)->uc_mcontext.__gregs[_REG_R3])

#define	_UC_MACHINE_SET_PC(uc, pc)	_UC_MACHINE_PC(uc) = (pc)

#if defined(_RTLD_SOURCE) || defined(_LIBC_SOURCE) || defined(__LIBPTHREAD_SOURCE__)
#include <sys/tls.h>

/*
 * On PowerPC, since displacements are signed 16-bit values, the TCB Pointer
 * is biased by 0x7000 + sizeof(tcb) so that first thread datum can be 
 * addressed by -28672 thereby leaving 60KB available for use as thread data.
 */
#define	TLS_TP_OFFSET	0x7000
#define	TLS_DTV_OFFSET	0x8000
__CTASSERT(TLS_TP_OFFSET + sizeof(struct tls_tcb) < 0x8000);

__BEGIN_DECLS

static __inline void *
__lwp_gettcb_fast(void)
{
	void *__tcb;

	__asm __volatile(
		"addi %[__tcb],%%r2,%[__offset]"
	    :	[__tcb] "=r" (__tcb)
	    :	[__offset] "n" (-(TLS_TP_OFFSET + sizeof(struct tls_tcb))));

	return __tcb;
}

void _lwp_setprivate(void *);

static __inline void
__lwp_settcb(void *__tcb)
{
	__tcb = (uint8_t *)__tcb + TLS_TP_OFFSET + sizeof(struct tls_tcb);

	__asm __volatile(
		"mr %%r2,%[__tcb]"
	    :
	    :	[__tcb] "r" (__tcb));

	_lwp_setprivate(__tcb);
}
__END_DECLS
#endif /* _RTLD_SOURCE || _LIBC_SOURCE || __LIBPTHREAD_SOURCE__ */

#endif	/* !_POWERPC_MCONTEXT_H_ */