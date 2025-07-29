/* $NetBSD: cpu.h,v 1.9 2022/11/17 09:50:23 simonb Exp $ */

/*-
 * Copyright (c) 2014 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Matt Thomas of 3am Software Foundry.
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

#ifndef _RISCV_CPU_H_
#define _RISCV_CPU_H_

#if defined(_KERNEL) || defined(_KMEMUSER)

struct clockframe {
	vaddr_t cf_epc;
	register_t cf_status;
	int cf_intr_depth;
};

#define CLKF_USERMODE(cf)	(((cf)->cf_status & SR_SPP) == 0)
#define CLKF_PC(cf)		((cf)->cf_epc)
#define CLKF_INTR(cf)		((cf)->cf_intr_depth > 0)

#include <sys/cpu_data.h>
#include <sys/device_if.h>
#include <sys/evcnt.h>
#include <sys/intr.h>

struct cpu_info {
	struct cpu_data ci_data;
	device_t ci_dev;
	cpuid_t ci_cpuid;
	struct lwp *ci_curlwp;
	struct lwp *ci_onproc;		/* current user LWP / kthread */
	struct lwp *ci_softlwps[SOFTINT_COUNT];
	struct trapframe *ci_ddb_regs;

	uint64_t ci_lastintr;

	int ci_mtx_oldspl;
	int ci_mtx_count;

	int ci_want_resched;
	int ci_cpl;
	u_int ci_softints;
	volatile u_int ci_intr_depth;

	tlb_asid_t ci_pmap_asid_cur;

	union pmap_segtab *ci_pmap_user_segtab;
#ifdef _LP64
	union pmap_segtab *ci_pmap_user_seg0tab;
#endif

	struct evcnt ci_ev_fpu_saves;
	struct evcnt ci_ev_fpu_loads;
	struct evcnt ci_ev_fpu_reenables;
#if defined(GPROF) && defined(MULTIPROCESSOR)
	struct gmonparam *ci_gmon;	/* MI per-cpu GPROF */
#endif
};

#endif /* _KERNEL || _KMEMUSER */

#ifdef _KERNEL

extern struct cpu_info cpu_info_store;

// This is also in <sys/lwp.h>
struct lwp;
static inline struct cpu_info *lwp_getcpu(struct lwp *);

register struct lwp *riscv_curlwp __asm("tp");
#define	curlwp		riscv_curlwp
#define	curcpu()	lwp_getcpu(curlwp)

static inline cpuid_t
cpu_number(void)
{
#ifdef MULTIPROCESSOR
	return curcpu()->ci_cpuid;
#else
	return 0;
#endif
}

void	cpu_proc_fork(struct proc *, struct proc *);
void	cpu_signotify(struct lwp *);
void	cpu_need_proftick(struct lwp *l);
void	cpu_boot_secondary_processors(void);

#define CPU_INFO_ITERATOR	cpuid_t
#ifdef MULTIPROCESSOR
#define CPU_INFO_FOREACH(cii, ci) \
	(cii) = 0; ((ci) = cpu_infos[cii]) != NULL; (cii)++
#else
#define CPU_INFO_FOREACH(cii, ci) \
	(cii) = 0, (ci) = curcpu(); (cii) == 0; (cii)++
#endif

#define CPU_INFO_CURPMAP(ci)	(curlwp->l_proc->p_vmspace->vm_map.pmap)

static inline void
cpu_dosoftints(void)
{
	extern void dosoftints(void);
        struct cpu_info * const ci = curcpu();
        if (ci->ci_intr_depth == 0
	    && (ci->ci_data.cpu_softints >> ci->ci_cpl) > 0)
                dosoftints();
}

static inline bool
cpu_intr_p(void)
{
	return curcpu()->ci_intr_depth > 0;
}

#define LWP_PC(l)	cpu_lwp_pc(l)

vaddr_t	cpu_lwp_pc(struct lwp *);

static inline void
cpu_idle(void)
{
}

#endif /* _KERNEL */

#endif /* _RISCV_CPU_H_ */