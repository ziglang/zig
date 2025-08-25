/*	$NetBSD: proc.h,v 1.19 2020/08/14 16:18:36 skrll Exp $	*/

/*
 * Copyright (c) 1994 Mark Brinicombe.
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
 *	This product includes software developed by the RiscBSD team.
 * 4. The name "RiscBSD" nor the name of the author may be used to
 *    endorse or promote products derived from this software without specific
 *    prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY RISCBSD ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL RISCBSD OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _ARM_PROC_H_
#define _ARM_PROC_H_

/*
 * Machine-dependent part of the proc structure for arm.
 */

struct trapframe;
struct lwp;

struct mdlwp {
	struct trapframe *md_tf;
	int	md_flags;
	volatile uint32_t md_astpending;
};

/* Flags setttings for md_flags */
#define MDLWP_NOALIGNFLT	0x00000002	/* For EXEC_AOUT */
#define MDLWP_VFPINTR		0x00000004	/* VFP used in intr */


struct mdproc {
	void	(*md_syscall)(struct trapframe *, struct lwp *, uint32_t);
	int	pmc_enabled;		/* bitfield of enabled counters */
	void	*pmc_state;		/* port-specific pmc state */
	char	md_march[12];		/* machine arch of executable */
};

#define	PROC_MACHINE_ARCH(P)	((P)->p_md.md_march)
#define	PROC0_MD_INITIALIZERS	.p_md = { .md_march = MACHINE_ARCH },

#endif /* _ARM_PROC_H_ */