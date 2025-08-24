/*	$NetBSD: cpu.h,v 1.123.4.1 2023/08/09 17:42:01 martin Exp $	*/

/*
 * Copyright (c) 1994-1996 Mark Brinicombe.
 * Copyright (c) 1994 Brini.
 * All rights reserved.
 *
 * This code is derived from software written for Brini by Mark Brinicombe
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
 *	This product includes software developed by Brini.
 * 4. The name of the company nor the name of the author may be used to
 *    endorse or promote products derived from this software without specific
 *    prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY BRINI ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL BRINI OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * RiscBSD kernel project
 *
 * cpu.h
 *
 * CPU specific symbols
 *
 * Created      : 18/09/94
 *
 * Based on kate/katelib/arm6.h
 */

#ifndef _ARM_CPU_H_
#define _ARM_CPU_H_

#ifdef _KERNEL
#ifndef _LOCORE

typedef unsigned long mpidr_t;

#ifdef MULTIPROCESSOR
extern u_int arm_cpu_max;
extern mpidr_t cpu_mpidr[];

void cpu_init_secondary_processor(int);
void cpu_boot_secondary_processors(void);
void cpu_mpstart(void);
bool cpu_hatched_p(u_int);

void cpu_clr_mbox(int);
void cpu_set_hatched(int);

#endif

struct proc;

void	cpu_proc_fork(struct proc *, struct proc *);

#endif	/* !_LOCORE */
#endif	/* _KERNEL */

#ifdef __arm__

/*
 * User-visible definitions
 */

/*  CTL_MACHDEP definitions. */
#define	CPU_DEBUG		1	/* int: misc kernel debug control */
#define	CPU_BOOTED_DEVICE	2	/* string: device we booted from */
#define	CPU_BOOTED_KERNEL	3	/* string: kernel we booted */
#define	CPU_CONSDEV		4	/* struct: dev_t of our console */
#define	CPU_POWERSAVE		5	/* int: use CPU powersave mode */

#if defined(_KERNEL) || defined(_KMEMUSER)

/*
 * Kernel-only definitions
 */

#if !defined(_MODULE) && defined(_KERNEL_OPT)
#include "opt_gprof.h"
#include "opt_multiprocessor.h"
#include "opt_cpuoptions.h"
#include "opt_lockdebug.h"
#include "opt_cputypes.h"
#endif /* !_MODULE && _KERNEL_OPT */

#ifndef _LOCORE
#if defined(TPIDRPRW_IS_CURLWP) || defined(TPIDRPRW_IS_CURCPU)
#include <arm/armreg.h>
#endif /* TPIDRPRW_IS_CURLWP || TPIDRPRW_IS_CURCPU */

/* 1 == use cpu_sleep(), 0 == don't */
extern int cpu_do_powersave;
extern int cpu_fpu_present;

/* All the CLKF_* macros take a struct clockframe * as an argument. */

/*
 * CLKF_USERMODE: Return TRUE/FALSE (1/0) depending on whether the
 * frame came from USR mode or not.
 */
#define CLKF_USERMODE(cf) (((cf)->cf_tf.tf_spsr & PSR_MODE) == PSR_USR32_MODE)

/*
 * CLKF_INTR: True if we took the interrupt from inside another
 * interrupt handler.
 */
#if !defined(__ARM_EABI__)
/* Hack to treat FPE time as interrupt time so we can measure it */
#define CLKF_INTR(cf)						\
	((curcpu()->ci_intr_depth > 1) ||			\
	    ((cf)->cf_tf.tf_spsr & PSR_MODE) == PSR_UND32_MODE)
#else
#define CLKF_INTR(cf)	((void)(cf), curcpu()->ci_intr_depth > 1)
#endif

/*
 * CLKF_PC: Extract the program counter from a clockframe
 */
#define CLKF_PC(frame)		(frame->cf_tf.tf_pc)

/*
 * LWP_PC: Find out the program counter for the given lwp.
 */
#define LWP_PC(l)		(lwp_trapframe(l)->tf_pc)

/*
 * Per-CPU information.  For now we assume one CPU.
 */
#ifdef _KERNEL
static inline int curcpl(void);
static inline void set_curcpl(int);
static inline void cpu_dosoftints(void);
#endif

#include <sys/param.h>

#ifdef _KMEMUSER
#include <sys/intr.h>
#endif
#include <sys/atomic.h>
#include <sys/cpu_data.h>
#include <sys/device_if.h>
#include <sys/evcnt.h>

/*
 * Cache info variables.
 */
#define	CACHE_TYPE_VIVT		0
#define	CACHE_TYPE_xxPT		1
#define	CACHE_TYPE_VIPT		1
#define	CACHE_TYPE_PIxx		2
#define	CACHE_TYPE_PIPT		3

/* PRIMARY CACHE VARIABLES */
struct arm_cache_info {
	u_int icache_size;
	u_int icache_line_size;
	u_int icache_ways;
	u_int icache_way_size;
	u_int icache_sets;

	u_int dcache_size;
	u_int dcache_line_size;
	u_int dcache_ways;
	u_int dcache_way_size;
	u_int dcache_sets;

	uint8_t cache_type;
	bool cache_unified;
	uint8_t icache_type;
	uint8_t dcache_type;
};

struct cpu_info {
	struct cpu_data	ci_data;	/* MI per-cpu data */
	device_t	ci_dev;		/* Device corresponding to this CPU */
	cpuid_t		ci_cpuid;
	uint32_t	ci_arm_cpuid;	/* aggregate CPU id */
	uint32_t	ci_arm_cputype;	/* CPU type */
	uint32_t	ci_arm_cpurev;	/* CPU revision */
	uint32_t	ci_ctrl;	/* The CPU control register */

	/*
	 * the following are in their own cache line, as they are stored to
	 * regularly by remote CPUs; when they were mixed with other fields
	 * we observed frequent cache misses.
	 */
	int		ci_want_resched __aligned(COHERENCY_UNIT);
					/* resched() was called */
	lwp_t *		ci_curlwp __aligned(COHERENCY_UNIT);
					/* current lwp */
	lwp_t *		ci_onproc;	/* current user LWP / kthread */

	/*
	 * largely CPU-private.
	 */
	lwp_t *		ci_softlwps[SOFTINT_COUNT] __aligned(COHERENCY_UNIT);

	struct cpu_softc *
			ci_softc;	/* platform softc */

	int		ci_cpl;		/* current processor level (spl) */
	volatile int	ci_hwpl;	/* current hardware priority */
	int		ci_kfpu_spl;

	volatile u_int	ci_intr_depth;	/* */
	volatile u_int	ci_softints;
	volatile uint32_t ci_blocked_pics;
	volatile uint32_t ci_pending_pics;
	volatile uint32_t ci_pending_ipls;

	lwp_t *		ci_lastlwp;	/* last lwp */

	struct evcnt	ci_arm700bugcount;
	int32_t		ci_mtx_count;
	int		ci_mtx_oldspl;
	register_t	ci_undefsave[3];
	uint32_t	ci_vfp_id;
	uint64_t	ci_lastintr;

	struct pmap_tlb_info *
			ci_tlb_info;
	struct pmap *	ci_pmap_lastuser;
	struct pmap *	ci_pmap_cur;
	tlb_asid_t	ci_pmap_asid_cur;

	struct trapframe *
			ci_ddb_regs;

	struct evcnt	ci_abt_evs[16];
	struct evcnt	ci_und_ev;
	struct evcnt	ci_und_cp15_ev;
	struct evcnt	ci_vfp_evs[3];

	uint32_t	ci_midr;
	uint32_t	ci_actlr;
	uint32_t	ci_revidr;
	uint32_t	ci_mpidr;
	uint32_t	ci_mvfr[2];

	uint32_t	ci_capacity_dmips_mhz;

	struct arm_cache_info
			ci_cacheinfo;

#if defined(GPROF) && defined(MULTIPROCESSOR)
	struct gmonparam *ci_gmon;	/* MI per-cpu GPROF */
#endif
};

extern struct cpu_info cpu_info_store[];

struct lwp *arm_curlwp(void);
struct cpu_info *arm_curcpu(void);

#ifdef _KERNEL
#if defined(_MODULE)

#define	curlwp		arm_curlwp()
#define curcpu()	arm_curcpu()

#elif defined(TPIDRPRW_IS_CURLWP)
static inline struct lwp *
_curlwp(void)
{
	return (struct lwp *) armreg_tpidrprw_read();
}

static inline void
_curlwp_set(struct lwp *l)
{
	armreg_tpidrprw_write((uintptr_t)l);
}

// Also in <sys/lwp.h> but also here if this was included before <sys/lwp.h>
static inline struct cpu_info *lwp_getcpu(struct lwp *);

#define	curlwp		_curlwp()
// curcpu() expands into two instructions: a mrc and a ldr
#define	curcpu()	lwp_getcpu(_curlwp())
#elif defined(TPIDRPRW_IS_CURCPU)
#ifdef __HAVE_PREEMPTION
#error __HAVE_PREEMPTION requires TPIDRPRW_IS_CURLWP
#endif
static inline struct cpu_info *
curcpu(void)
{
	return (struct cpu_info *) armreg_tpidrprw_read();
}
#elif !defined(MULTIPROCESSOR)
#define	curcpu()	(&cpu_info_store[0])
#elif !defined(__HAVE_PREEMPTION)
#error MULTIPROCESSOR && !__HAVE_PREEMPTION requires TPIDRPRW_IS_CURCPU or TPIDRPRW_IS_CURLWP
#else
#error MULTIPROCESSOR && __HAVE_PREEMPTION requires TPIDRPRW_IS_CURLWP
#endif /* !TPIDRPRW_IS_CURCPU && !TPIDRPRW_IS_CURLWP */

#ifndef curlwp
#define	curlwp		(curcpu()->ci_curlwp)
#endif
#define curpcb		((struct pcb *)lwp_getpcb(curlwp))

#define CPU_INFO_ITERATOR	int
#if defined(_MODULE) || defined(MULTIPROCESSOR)
extern struct cpu_info *cpu_info[];
#define cpu_number()		(curcpu()->ci_index)
#define CPU_IS_PRIMARY(ci)	((ci)->ci_index == 0)
#define CPU_INFO_FOREACH(cii, ci)			\
	cii = 0, ci = cpu_info[0]; cii < (ncpu ? ncpu : 1) && (ci = cpu_info[cii]) != NULL; cii++
#else
#define cpu_number()            0

#define CPU_IS_PRIMARY(ci)	true
#define CPU_INFO_FOREACH(cii, ci)			\
	cii = 0, __USE(cii), ci = curcpu(); ci != NULL; ci = NULL
#endif

#define	LWP0_CPU_INFO	(&cpu_info_store[0])

static inline int
curcpl(void)
{
	return curcpu()->ci_cpl;
}

static inline void
set_curcpl(int pri)
{
	curcpu()->ci_cpl = pri;
}

static inline void
cpu_dosoftints(void)
{
#ifdef __HAVE_FAST_SOFTINTS
	void	dosoftints(void);
#ifndef __HAVE_PIC_FAST_SOFTINTS
	struct cpu_info * const ci = curcpu();
	if (ci->ci_intr_depth == 0 && (ci->ci_softints >> ci->ci_cpl) > 0)
		dosoftints();
#endif
#endif
}

/*
 * Scheduling glue
 */
void cpu_signotify(struct lwp *);
#define	setsoftast(ci)		(cpu_signotify((ci)->ci_onproc))

/*
 * Give a profiling tick to the current process when the user profiling
 * buffer pages are invalid.  On the i386, request an ast to send us
 * through trap(), marking the proc as needing a profiling tick.
 */
#define	cpu_need_proftick(l)	((l)->l_pflag |= LP_OWEUPC, \
				 setsoftast(lwp_getcpu(l)))

/*
 * We've already preallocated the stack for the idlelwps for additional CPUs.
 * This hook allows to return them.
 */
vaddr_t cpu_uarea_alloc_idlelwp(struct cpu_info *);

#ifdef _ARM_ARCH_6
int	cpu_maxproc_hook(int);
#endif

#endif /* _KERNEL */

#endif /* !_LOCORE */

#endif /* _KERNEL || _KMEMUSER */

#elif defined(__aarch64__)

#include <aarch64/cpu.h>

#endif /* __arm__/__aarch64__ */

#endif /* !_ARM_CPU_H_ */