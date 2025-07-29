/*	$NetBSD: fpu.h,v 1.25 2020/07/15 09:19:49 rin Exp $	*/

/*-
 * Copyright (C) 1996 Wolfgang Solfrank.
 * Copyright (C) 1996 TooLs GmbH.
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

#ifndef	_POWERPC_FPU_H_
#define	_POWERPC_FPU_H_

#define	FPSCR_FX	0x80000000	/* Exception Summary */
#define	FPSCR_FEX	0x40000000	/* Enabled Exception Summary */
#define	FPSCR_VX	0x20000000	/* Invalid Operation Exception Summary */
#define	FPSCR_OX	0x10000000	/* Overflow Exception */
#define	FPSCR_UX	0x08000000	/* Undrflow Exception */
#define	FPSCR_ZX	0x04000000	/* Zero Divide Exception */
#define	FPSCR_XX	0x02000000	/* Inexact Exception */
#define	FPSCR_VXSNAN	0x01000000	/* Invalid Op (NAN) */
#define	FPSCR_VXISI	0x00800000	/* Invalid Op (INF-INF) */
#define	FPSCR_VXIDI	0x00400000	/* Invalid Op (INF/INF) */
#define	FPSCR_VXZDZ	0x00200000	/* Invalid Op (0/0) */
#define	FPSCR_VXIMZ	0x00100000	/* Invalid Op (INFx0) */
#define	FPSCR_VXVC	0x00080000	/* Invalid Compare Op */
#define	FPSCR_FR	0x00040000	/* Fraction Rounded */
#define	FPSCR_FI	0x00020000	/* Fraction Inexact */
#define	FPSCR_FPRF	0x0001f000
#define	FPSCR_C		0x00010000	/* FP Class Descriptor */
#define	FPSCR_FPCC	0x0000f000
#define	FPSCR_FL	0x00008000	/* < */
#define	FPSCR_FG	0x00004000	/* > */
#define	FPSCR_FE	0x00002000	/* == */
#define	FPSCR_FU	0x00001000	/* unordered */
#define	FPSCR_VXSOFT	0x00000400	/* Software Invalid Exception */
#define	FPSCR_VXSQRT	0x00000200	/* Invalid Sqrt Exception */
#define	FPSCR_VXCVI	0x00000100	/* Invalid Op Integer Cvt Exception */
#define	FPSCR_VE	0x00000080	/* Invalid Op Exception Enable */
#define	FPSCR_OE	0x00000040	/* Overflow Exception Enable */
#define	FPSCR_UE	0x00000020	/* Underflow Exception Enable */
#define	FPSCR_ZE	0x00000010	/* Zero Divide Exception Enable */
#define	FPSCR_XE	0x00000008	/* Inexact Exception Enable */
#define	FPSCR_NI	0x00000004	/* Non-IEEE Mode Enable */
#define	FPSCR_RN	0x00000003

#ifdef _KERNEL

#ifdef _KERNEL_OPT
#include "opt_ppcarch.h"
#endif

#include <sys/pcu.h>
#include <powerpc/mcontext.h>

struct lwp;
bool	fpu_used_p(struct lwp *);
void	fpu_mark_used(struct lwp *);

void	fpu_restore_from_mcontext(struct lwp *, const mcontext_t *);
bool	fpu_save_to_mcontext(struct lwp *, mcontext_t *, unsigned int *);

int	fpu_get_fault_code(void);

extern const pcu_ops_t fpu_ops;

/* List of PowerPC architectures that support FPUs. */
#if defined(PPC_OEA) || defined (PPC_OEA64) || defined (PPC_OEA64_BRIDGE)
#define PPC_HAVE_FPU

struct fpreg;

static __inline void
fpu_load(void)
{
	pcu_load(&fpu_ops);
}

static __inline void
fpu_save(lwp_t *l)
{
	pcu_save(&fpu_ops, l);
}

static __inline void
fpu_discard(lwp_t *l)
{
	pcu_discard(&fpu_ops, l, false);
}

void	fpu_load_from_fpreg(const struct fpreg *);
void	fpu_unload_to_fpreg(struct fpreg *);

#endif /* PPC_HAVE_FPU */
#endif /* _KERNEL */

#endif	/* _POWERPC_FPU_H_ */