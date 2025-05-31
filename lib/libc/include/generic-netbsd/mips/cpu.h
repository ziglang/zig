/*	$NetBSD: cpu.h,v 1.133 2021/08/14 17:51:19 ryo Exp $	*/

/*-
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Ralph Campbell and Rick Macklem.
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
 *	@(#)cpu.h	8.4 (Berkeley) 1/4/94
 */

#ifndef _CPU_H_
#define	_CPU_H_

/*
 * Exported definitions unique to NetBSD/mips cpu support.
 */

#ifdef _LOCORE
#error Use assym.h to get definitions from <mips/cpu.h>
#endif

#if defined(_KERNEL) || defined(_KMEMUSER)

#if defined(_KERNEL_OPT)
#include "opt_cputype.h"
#include "opt_gprof.h"
#include "opt_lockdebug.h"
#include "opt_multiprocessor.h"
#endif

#include <mips/frame.h>

#include <sys/cpu_data.h>
#include <sys/device_if.h>
#include <sys/evcnt.h>
#include <sys/kcpuset.h>
#include <sys/intr.h>

typedef struct cpu_watchpoint {
	register_t	cw_addr;
	register_t	cw_mask;
	uint32_t	cw_asid;
	uint32_t	cw_mode;
} cpu_watchpoint_t;

/* (abstract) mode bits */
#define	CPUWATCH_WRITE	__BIT(0)
#define	CPUWATCH_READ	__BIT(1)
#define	CPUWATCH_EXEC	__BIT(2)
#define	CPUWATCH_MASK	__BIT(3)
#define	CPUWATCH_ASID	__BIT(4)
#define	CPUWATCH_RWX	(CPUWATCH_EXEC|CPUWATCH_READ|CPUWATCH_WRITE)

#define	CPUWATCH_MAX	8	/* max possible number of watchpoints */

u_int		  cpuwatch_discover(void);
void		  cpuwatch_free(cpu_watchpoint_t *);
cpu_watchpoint_t *cpuwatch_alloc(void);
void		  cpuwatch_set_all(void);
void		  cpuwatch_clr_all(void);
void		  cpuwatch_set(cpu_watchpoint_t *);
void		  cpuwatch_clr(cpu_watchpoint_t *);

struct cpu_info {
	struct cpu_data ci_data;	/* MI per-cpu data */
	void *ci_nmi_stack;		/* NMI exception stack */
	struct cpu_softc *ci_softc;	/* chip-dependent hook */
	device_t ci_dev;		/* owning device */
	cpuid_t ci_cpuid;		/* Machine-level identifier */
	u_long ci_cctr_freq;		/* cycle counter frequency */
	u_long ci_cpu_freq;		/* CPU frequency */
	u_long ci_cycles_per_hz;	/* CPU freq / hz */
	u_long ci_divisor_delay;	/* for delay/DELAY */
	u_long ci_divisor_recip;	/* unused, for obsolete microtime(9) */
	struct lwp *ci_curlwp;		/* currently running lwp */
	struct lwp *ci_onproc;		/* current user LWP / kthread */
	volatile int ci_want_resched;	/* user preemption pending */
	int ci_mtx_count;		/* negative count of held mutexes */
	int ci_mtx_oldspl;		/* saved SPL value */
	int ci_idepth;			/* hardware interrupt depth */
	int ci_cpl;			/* current [interrupt] priority level */
	uint32_t ci_next_cp0_clk_intr;	/* for hard clock intr scheduling */
	struct evcnt ci_ev_count_compare;		/* hard clock intr counter */
	struct evcnt ci_ev_count_compare_missed;	/* hard clock miss counter */
	struct lwp *ci_softlwps[SOFTINT_COUNT];
	volatile u_int ci_softints;
	struct evcnt ci_ev_fpu_loads;	/* fpu load counter */
	struct evcnt ci_ev_fpu_saves;	/* fpu save counter */
	struct evcnt ci_ev_dsp_loads;	/* dsp load counter */
	struct evcnt ci_ev_dsp_saves;	/* dsp save counter */
	struct evcnt ci_ev_tlbmisses;

	/*
	 * Per-cpu pmap information
	 */
	int ci_tlb_slot;		/* reserved tlb entry for cpu_info */
	u_int ci_pmap_asid_cur;		/* current ASID */
	struct pmap_tlb_info *ci_tlb_info; /* tlb information for this cpu */
	union pmap_segtab *ci_pmap_segtabs[2];
#define	ci_pmap_user_segtab	ci_pmap_segtabs[0]
#define	ci_pmap_kern_segtab	ci_pmap_segtabs[1]
#ifdef _LP64
	union pmap_segtab *ci_pmap_seg0tabs[2];
#define	ci_pmap_user_seg0tab	ci_pmap_seg0tabs[0]
#define	ci_pmap_kern_seg0tab	ci_pmap_seg0tabs[1]
#endif
	vaddr_t ci_pmap_srcbase;	/* starting VA of ephemeral src space */
	vaddr_t ci_pmap_dstbase;	/* starting VA of ephemeral dst space */

	u_int ci_cpuwatch_count;	/* number of watchpoints on this CPU */
	cpu_watchpoint_t ci_cpuwatch_tab[CPUWATCH_MAX];

#ifdef MULTIPROCESSOR
	volatile u_long ci_flags;
	volatile uint64_t ci_request_ipis;
					/* bitmask of IPIs requested */
					/*  use on chips where hw cannot pass tag */
	uint64_t ci_active_ipis;	/* bitmask of IPIs being serviced */
	uint32_t ci_ksp_tlb_slot;	/* tlb entry for kernel stack */
	struct evcnt ci_evcnt_all_ipis;	/* aggregated IPI counter */
	struct evcnt ci_evcnt_per_ipi[NIPIS];	/* individual IPI counters*/
	struct evcnt ci_evcnt_synci_activate_rqst;
	struct evcnt ci_evcnt_synci_onproc_rqst;
	struct evcnt ci_evcnt_synci_deferred_rqst;
	struct evcnt ci_evcnt_synci_ipi_rqst;

#define	CPUF_PRIMARY	0x01		/* CPU is primary CPU */
#define	CPUF_PRESENT	0x02		/* CPU is present */
#define	CPUF_RUNNING	0x04		/* CPU is running */
#define	CPUF_PAUSED	0x08		/* CPU is paused */
#define	CPUF_USERPMAP	0x20		/* CPU has a user pmap activated */
	kcpuset_t *ci_shootdowncpus;
	kcpuset_t *ci_multicastcpus;
	kcpuset_t *ci_watchcpus;
	kcpuset_t *ci_ddbcpus;
#endif
#if defined(GPROF) && defined(MULTIPROCESSOR)
	struct gmonparam *ci_gmon;	/* MI per-cpu GPROF */
#endif

};
#endif /* _KERNEL || _KMEMUSER */

#ifdef _KERNEL

#ifdef MULTIPROCESSOR
#define	CPU_INFO_ITERATOR		int
#define	CPU_INFO_FOREACH(cii, ci)	\
    cii = 0, ci = &cpu_info_store; \
    ci != NULL; \
    cii++, \
    ncpu ? (ci = cpu_infos[cii]) \
         : (ci = NULL)
#else
#define	CPU_INFO_ITERATOR		int __unused
#define	CPU_INFO_FOREACH(cii, ci)	\
    ci = &cpu_info_store; ci != NULL; ci = NULL
#endif

/* Note: must be kept in sync with -ffixed-?? Makefile.mips. */
//	MIPS_CURLWP moved to <mips/regdef.h>
#define	MIPS_CURLWP_QUOTED	"$24"
#define	MIPS_CURLWP_LABEL	_L_T8
#define	MIPS_CURLWP_REG		_R_T8

extern struct cpu_info cpu_info_store;
#ifdef MULTIPROCESSOR
extern struct cpu_info *cpuid_infos[];
#endif
register struct lwp *mips_curlwp asm(MIPS_CURLWP_QUOTED);

#define	curlwp			mips_curlwp
#define	curcpu()		lwp_getcpu(curlwp)
#define	curpcb			((struct pcb *)lwp_getpcb(curlwp))
#ifdef MULTIPROCESSOR
#define	cpu_number()		(curcpu()->ci_index)
#define	CPU_IS_PRIMARY(ci)	((ci)->ci_flags & CPUF_PRIMARY)
#else
#define	cpu_number()		(0)
#define	CPU_IS_PRIMARY(ci)	(true)
#endif

/*
 * definitions of cpu-dependent requirements
 * referenced in generic code
 */

/*
 * Send an inter-processor interrupt to each other CPU (excludes curcpu())
 */
void cpu_broadcast_ipi(int);

/*
 * Send an inter-processor interrupt to CPUs in kcpuset (excludes curcpu())
 */
void cpu_multicast_ipi(const kcpuset_t *, int);

/*
 * Send an inter-processor interrupt to another CPU.
 */
int cpu_send_ipi(struct cpu_info *, int);

/*
 * cpu_intr(ppl, pc, status);  (most state needed by clockframe)
 */
void cpu_intr(int, vaddr_t, uint32_t);

/*
 * Arguments to hardclock and gatherstats encapsulate the previous
 * machine state in an opaque clockframe.
 */
struct clockframe {
	vaddr_t		pc;	/* program counter at time of interrupt */
	uint32_t	sr;	/* status register at time of interrupt */
	bool		intr;	/* interrupted a interrupt */
};

/*
 * A port must provde CLKF_USERMODE() for use in machine-independent code.
 * These differ on r4000 and r3000 systems; provide them in the
 * port-dependent file that includes this one, using the macros below.
 */
uint32_t cpu_clkf_usermode_mask(void);

#define	CLKF_USERMODE(framep)	((framep)->sr & cpu_clkf_usermode_mask())
#define	CLKF_PC(framep)		((framep)->pc + 0)
#define	CLKF_INTR(framep)	((framep)->intr + 0)

/*
 * Misc prototypes and variable declarations.
 */
#define	LWP_PC(l)	cpu_lwp_pc(l)

struct proc;
struct lwp;
struct pcb;
struct reg;

/*
 * Notify the current lwp (l) that it has a signal pending,
 * process as soon as possible.
 */
void	cpu_signotify(struct lwp *);

/*
 * Give a profiling tick to the current process when the user profiling
 * buffer pages are invalid.  On the MIPS, request an ast to send us
 * through trap, marking the proc as needing a profiling tick.
 */
void	cpu_need_proftick(struct lwp *);

/* VM related hooks */
void	cpu_boot_secondary_processors(void);
void *	cpu_uarea_alloc(bool);
bool	cpu_uarea_free(void *);
void	cpu_proc_fork(struct proc *, struct proc *);
vaddr_t	cpu_lwp_pc(struct lwp *);
#ifdef _LP64
void	cpu_vmspace_exec(struct lwp *, vaddr_t, vaddr_t);
#endif

#endif /* _KERNEL */

/*
 * CTL_MACHDEP definitions.
 */
#define	CPU_CONSDEV		1	/* dev_t: console terminal device */
#define	CPU_BOOTED_KERNEL	2	/* string: booted kernel name */
#define	CPU_ROOT_DEVICE		3	/* string: root device name */
#define	CPU_LLSC		4	/* OS/CPU supports LL/SC instruction */
#define	CPU_LMMI		5	/* Loongson multimedia instructions */

#endif /* _CPU_H_ */