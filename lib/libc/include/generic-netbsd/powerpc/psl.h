/*	$NetBSD: psl.h,v 1.22 2021/03/06 08:08:19 rin Exp $	*/

/*
 * Copyright (C) 1995, 1996 Wolfgang Solfrank.
 * Copyright (C) 1995, 1996 TooLs GmbH.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by TooLs GmbH.
 * 4. The name of TooLs GmbH may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY TOOLS GMBH ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL TOOLS GMBH BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef	_POWERPC_PSL_H_
#define	_POWERPC_PSL_H_

/*
 * Machine State Register (MSR)
 *
 * The PowerPC 601 does not implement the following bits:
 *
 *	VEC, POW, ILE, BE, RI, LE[*]
 *
 * [*] Little-endian mode on the 601 is implemented in the HID0 register.
 */
#define	PSL_VEC		0x02000000	/* ..6. AltiVec vector unit available */
#define	PSL_SPV		0x02000000	/* B... (e500) SPE enable */
#define	PSL_UCLE	0x00400000	/* B... user-mode cache lock enable */
#define	PSL_POW		0x00040000	/* ..6. power management */
#define	PSL_WE		PSL_POW		/* B4.. wait state enable */
#define	PSL_TGPR	0x00020000	/* ..6. temp. gpr remapping (mpc603e) */
#define	PSL_CE		PSL_TGPR	/* B4.. critical interrupt enable */
#define	PSL_ILE		0x00010000	/* ..6. interrupt endian mode (1 == le) */
#define	PSL_EE		0x00008000	/* B468 external interrupt enable */
#define	PSL_PR		0x00004000	/* B468 privilege mode (1 == user) */
#define	PSL_FP		0x00002000	/* B.6. floating point enable */
#define	PSL_ME		0x00001000	/* B468 machine check enable */
#define	PSL_FE0		0x00000800	/* B.6. floating point mode 0 */
#define	PSL_SE		0x00000400	/* ..6. single-step trace enable */
#define	PSL_DWE		PSL_SE		/* .4.. debug wait enable */
#define	PSL_UBLE	PSL_SE		/* B... user BTB lock enable */
#define	PSL_BE		0x00000200	/* ..6. branch trace enable */
#define	PSL_DE		PSL_BE		/* B4.. debug interrupt enable */
#define	PSL_FE1		0x00000100	/* B.6. floating point mode 1 */
#define	PSL_IP		0x00000040	/* ..6. interrupt prefix */
#define	PSL_IR		0x00000020	/* .468 instruction address relocation */
#define	PSL_IS		PSL_IR		/* B... instruction address space */
#define	PSL_DR		0x00000010	/* .468 data address relocation */
#define	PSL_DS		PSL_DR		/* B... data address space */
#define	PSL_PM		0x00000008	/* ..6. Performance monitor */
#define	PSL_PMM		PSL_PM		/* B... Performance monitor */
#define	PSL_RI		0x00000002	/* ..6. recoverable interrupt */
#define	PSL_LE		0x00000001	/* ..6. endian mode (1 == le) */

#define	PSL_601_MASK	~(PSL_VEC|PSL_POW|PSL_ILE|PSL_BE|PSL_RI|PSL_LE)

/* The IBM 970 series does not implemnt LE mode */
#define PSL_970_MASK	~(PSL_ILE|PSL_LE)

/*
 * Floating-point exception modes:
 */
#define	PSL_FE_DIS	0		/* none */
#define	PSL_FE_NONREC	PSL_FE1		/* imprecise non-recoverable */
#define	PSL_FE_REC	PSL_FE0		/* imprecise recoverable */
#define	PSL_FE_PREC	(PSL_FE0 | PSL_FE1) /* precise */
#define	PSL_FE_DFLT	PSL_FE_DIS	/* default == none */

/*
 * Note that PSL_POW and PSL_ILE are not in the saved copy of the MSR
 */
#define	PSL_MBO		0
#define	PSL_MBZ		0

/*
 * A user is not allowed to change any MSR bits except the following:
 * We restrict the test to the low 16 bits of the MSR since those are the
 * only ones preserved in the trap.  Note that this means PSL_VEC needs to
 * be restored to SRR1 in userret.
 */
#if defined(_KERNEL) && !defined(_LOCORE)
#ifdef _KERNEL_OPT
#include "opt_ppcarch.h"
#endif /* _KERNEL_OPT */

#if defined(PPC_OEA) || defined (PPC_OEA64_BRIDGE) || defined (PPC_OEA64) \
    || defined(_MODULE)
extern register_t cpu_psluserset, cpu_pslusermod, cpu_pslusermask;

#define	PSL_USERSET		cpu_psluserset
#define	PSL_USERMOD		cpu_pslusermod
#define	PSL_USERMASK		cpu_pslusermask
#elif defined(PPC_BOOKE)
#define	PSL_USERSET		(PSL_EE | PSL_PR | PSL_IS | PSL_DS | PSL_ME | PSL_CE)
#define	PSL_USERMASK		(PSL_SPV | PSL_CE | 0xFFFF)
#define	PSL_USERMOD		(0)
#else /* PPC_IBM4XX */
#ifdef PPC_IBM403
#define	PSL_USERSET		(PSL_EE | PSL_PR | PSL_IR | PSL_DR | PSL_ME)
#else /* Apparently we get unexplained machine checks, so disable them. */
#define	PSL_USERSET		(PSL_EE | PSL_PR | PSL_IR | PSL_DR)
#endif
#define	PSL_USERMASK		0xFFFF
#define	PSL_USERMOD		(0)
#endif

#define	PSL_USERSRR1		((PSL_USERSET|PSL_USERMOD) & PSL_USERMASK)
#define	PSL_USEROK_P(psl)	(((psl) & ~PSL_USERMOD) == PSL_USERSET)
#endif /* !_LOCORE */

#endif	/* _POWERPC_PSL_H_ */