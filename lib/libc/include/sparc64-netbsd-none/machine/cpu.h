/*	$NetBSD: cpu.h,v 1.133.4.1 2023/08/09 17:42:03 martin Exp $ */

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
 *	@(#)cpu.h	8.4 (Berkeley) 1/5/94
 */

#ifndef _CPU_H_
#define _CPU_H_

/*
 * CTL_MACHDEP definitions.
 */
#define	CPU_BOOTED_KERNEL	1	/* string: booted kernel name */
#define	CPU_BOOTED_DEVICE	2	/* string: device booted from */
#define	CPU_BOOT_ARGS		3	/* string: args booted with */
#define	CPU_ARCH		4	/* integer: cpu architecture version */
#define CPU_VIS			5	/* 0 - no VIS, 1 - VIS 1.0, etc. */

/*
 * This is exported via sysctl for cpuctl(8).
 */
struct cacheinfo {
	int 	c_itotalsize;
	int 	c_ilinesize;
	int 	c_dtotalsize;
	int 	c_dlinesize;
	int 	c_etotalsize;
	int 	c_elinesize;
};

#if defined(_KERNEL) || defined(_KMEMUSER)
/*
 * Exported definitions unique to SPARC cpu support.
 */

#if defined(_KERNEL_OPT)
#include "opt_gprof.h"
#include "opt_multiprocessor.h"
#include "opt_lockdebug.h"
#endif

#include <machine/psl.h>
#include <machine/reg.h>
#include <machine/pte.h>
#include <machine/intr.h>
#if defined(_KERNEL)
#include <machine/bus_defs.h>
#include <machine/cpuset.h>
#include <sparc64/sparc64/intreg.h>
#endif
#ifdef SUN4V
#include <machine/hypervisor.h>
#endif

#include <sys/cpu_data.h>
#include <sys/mutex.h>
#include <sys/evcnt.h>

/*
 * The cpu_info structure is part of a 64KB structure mapped both the kernel
 * pmap and a single locked TTE a CPUINFO_VA for that particular processor.
 * Each processor's cpu_info is accessible at CPUINFO_VA only for that
 * processor.  Other processors can access that through an additional mapping
 * in the kernel pmap.
 *
 * The 64KB page contains:
 *
 * cpu_info
 * interrupt stack (all remaining space)
 * idle PCB
 * idle stack (STACKSPACE - sizeof(PCB))
 * 32KB TSB
 */

struct cpu_info {
	struct cpu_data		ci_data;	/* MI per-cpu data */


	/*
	 * SPARC cpu_info structures live at two VAs: one global
	 * VA (so each CPU can access any other CPU's cpu_info)
	 * and an alias VA CPUINFO_VA which is the same on each
	 * CPU and maps to that CPU's cpu_info.  Since the alias
	 * CPUINFO_VA is how we locate our cpu_info, we have to
	 * self-reference the global VA so that we can return it
	 * in the curcpu() macro.
	 */
	struct cpu_info * volatile ci_self;

	/* Most important fields first */
	struct lwp		*ci_curlwp;
	struct lwp		*ci_onproc;	/* current user LWP / kthread */
	struct pcb		*ci_cpcb;
	struct cpu_info		*ci_next;

	struct lwp		*ci_fplwp;

	void			*ci_eintstack;

	int			ci_mtx_count;
	int			ci_mtx_oldspl;

	/* Spinning up the CPU */
	void			(*ci_spinup)(void);
	paddr_t			ci_paddr;

	int			ci_cpuid;

	uint64_t		ci_ver;

	/* CPU PROM information. */
	u_int			ci_node;
	const char		*ci_name;

	/* This is for sysctl. */
	struct cacheinfo	ci_cacheinfo;

	/* %tick and cpu frequency information */
	u_long			ci_tick_increment;
	uint64_t		ci_cpu_clockrate[2];	/* %tick */
	uint64_t		ci_system_clockrate[2];	/* %stick */

	/* Interrupts */
	struct intrhand		*ci_intrpending[16];
	struct intrhand		*ci_tick_ih;

	/* Event counters */
	struct evcnt		ci_tick_evcnt;

	/* This could be under MULTIPROCESSOR, but there's no good reason */
	struct evcnt		ci_ipi_evcnt[IPI_EVCNT_NUM];

	int			ci_flags;
	int			ci_want_ast;
	int			ci_want_resched;
	int			ci_idepth;

/*
 * A context is simply a small number that differentiates multiple mappings
 * of the same address.  Contexts on the spitfire are 13 bits, but could
 * be as large as 17 bits.
 *
 * Each context is either free or attached to a pmap.
 *
 * The context table is an array of pointers to psegs.  Just dereference
 * the right pointer and you get to the pmap segment tables.  These are
 * physical addresses, of course.
 *
 * ci_ctx_lock protects this CPUs context allocation/free.
 * These are all allocated almost with in the same cacheline.
 */
	kmutex_t		ci_ctx_lock;
	int			ci_pmap_next_ctx;
	int			ci_numctx;
	paddr_t 		*ci_ctxbusy;
	LIST_HEAD(, pmap) 	ci_pmap_ctxlist;

	/*
	 * The TSBs are per cpu too (since MMU context differs between
	 * cpus). These are just caches for the TLBs.
	 */
	pte_t			*ci_tsb_dmmu;
	pte_t			*ci_tsb_immu;

	/* TSB description (sun4v). */
	struct tsb_desc         *ci_tsb_desc;

	/* MMU Fault Status Area (sun4v).
	 * Will be initialized to the physical address of the bottom of
	 * the interrupt stack.
	 */
	paddr_t			ci_mmufsa;

	/*
	 * sun4v mondo control fields
	 */
	paddr_t			ci_cpumq;  /* cpu mondo queue address */
	paddr_t			ci_devmq;  /* device mondo queue address */
	paddr_t			ci_cpuset; /* mondo recipient address */ 
	paddr_t			ci_mondo;  /* mondo message address */

	/* probe fault in PCI config space reads */
	bool			ci_pci_probe;
	bool			ci_pci_fault;

	volatile void		*ci_ddb_regs;	/* DDB regs */

	void (*ci_idlespin)(void);

#if defined(GPROF) && defined(MULTIPROCESSOR)
	struct gmonparam *ci_gmon;	/* MI per-cpu GPROF */
#endif
};

#endif /* _KERNEL || _KMEMUSER */

#ifdef _KERNEL

#define CPUF_PRIMARY	1

/*
 * CPU boot arguments. Used by secondary CPUs at the bootstrap time.
 */
struct cpu_bootargs {
	u_int	cb_node;	/* PROM CPU node */
	volatile int cb_flags;

	vaddr_t cb_ktext;
	paddr_t cb_ktextp;
	vaddr_t cb_ektext;

	vaddr_t cb_kdata;
	paddr_t cb_kdatap;
	vaddr_t cb_ekdata;

	paddr_t	cb_cpuinfo;
	int cb_cputyp;
};

extern struct cpu_bootargs *cpu_args;

#if defined(MULTIPROCESSOR)
extern int sparc_ncpus;
#else
#define sparc_ncpus 1
#endif

extern struct cpu_info *cpus;
extern struct pool_cache *fpstate_cache;

/* CURCPU_INT() a local (per CPU) view of our cpu_info */
#define	CURCPU_INT()	((struct cpu_info *)CPUINFO_VA)
/* in general we prefer the globaly visible pointer */
#define	curcpu()	(CURCPU_INT()->ci_self)
#define	cpu_number()	(curcpu()->ci_index)
#define	CPU_IS_PRIMARY(ci)	((ci)->ci_flags & CPUF_PRIMARY)

#define CPU_INFO_ITERATOR		int __unused
#define CPU_INFO_FOREACH(cii, ci)	ci = cpus; ci != NULL; ci = ci->ci_next

/* these are only valid on the local cpu */
#define curlwp		CURCPU_INT()->ci_curlwp
#define fplwp		CURCPU_INT()->ci_fplwp
#define curpcb		CURCPU_INT()->ci_cpcb
#define want_ast	CURCPU_INT()->ci_want_ast

/*
 * definitions of cpu-dependent requirements
 * referenced in generic code
 */
#define	cpu_wait(p)	/* nothing */
void cpu_proc_fork(struct proc *, struct proc *);

/* run on the cpu itself */
void	cpu_pmap_init(struct cpu_info *);
/* run upfront to prepare the cpu_info */
void	cpu_pmap_prepare(struct cpu_info *, bool);

/* Helper functions to retrieve cache info */
int	cpu_ecache_associativity(int node);
int	cpu_ecache_size(int node);

#if defined(MULTIPROCESSOR)
extern vaddr_t cpu_spinup_trampoline;

extern  char   *mp_tramp_code;
extern  u_long  mp_tramp_code_len;
extern  u_long  mp_tramp_dtlb_slots, mp_tramp_itlb_slots;
extern  u_long  mp_tramp_func;
extern  u_long  mp_tramp_ci;

void	cpu_hatch(void);
void	cpu_boot_secondary_processors(void);

/*
 * Call a function on other cpus:
 *	multicast - send to everyone in the sparc64_cpuset_t
 *	broadcast - send to to all cpus but ourselves
 *	send - send to just this cpu
 * The called function do not follow the C ABI, so need to be coded in
 * assembler.
 */
typedef void (* ipifunc_t)(void *, void *);

void	sparc64_multicast_ipi(sparc64_cpuset_t, ipifunc_t, uint64_t, uint64_t);
void	sparc64_broadcast_ipi(ipifunc_t, uint64_t, uint64_t);
extern void (*sparc64_send_ipi)(int, ipifunc_t, uint64_t, uint64_t);

/*
 * Call an arbitrary C function on another cpu (or all others but ourself)
 */
typedef void (*ipi_c_call_func_t)(void*);
void	sparc64_generic_xcall(struct cpu_info*, ipi_c_call_func_t, void*);

#endif

/* Provide %pc of a lwp */
#define	LWP_PC(l)	((l)->l_md.md_tf->tf_pc)

/*
 * Arguments to hardclock, softclock and gatherstats encapsulate the
 * previous machine state in an opaque clockframe.  The ipl is here
 * as well for strayintr (see locore.s:interrupt and intr.c:strayintr).
 * Note that CLKF_INTR is valid only if CLKF_USERMODE is false.
 */
struct clockframe {
	struct trapframe64 t;
};

#define	CLKF_USERMODE(framep)	(((framep)->t.tf_tstate & TSTATE_PRIV) == 0)
#define	CLKF_PC(framep)		((framep)->t.tf_pc)
/* Since some files in sys/kern do not know BIAS, I'm using 0x7ff here */
#define	CLKF_INTR(framep)						\
	((!CLKF_USERMODE(framep))&&					\
		(((framep)->t.tf_out[6] & 1 ) ?				\
			(((vaddr_t)(framep)->t.tf_out[6] <		\
				(vaddr_t)EINTSTACK-0x7ff) &&		\
			((vaddr_t)(framep)->t.tf_out[6] >		\
				(vaddr_t)INTSTACK-0x7ff)) :		\
			(((vaddr_t)(framep)->t.tf_out[6] <		\
				(vaddr_t)EINTSTACK) &&			\
			((vaddr_t)(framep)->t.tf_out[6] >		\
				(vaddr_t)INTSTACK))))

/*
 * Give a profiling tick to the current process when the user profiling
 * buffer pages are invalid.  On the sparc, request an ast to send us
 * through trap(), marking the proc as needing a profiling tick.
 */
#define	cpu_need_proftick(l)	((l)->l_pflag |= LP_OWEUPC, want_ast = 1)

/*
 * Notify an LWP that it has a signal pending, process as soon as possible.
 */
void cpu_signotify(struct lwp *);


/*
 * Interrupt handler chains.  Interrupt handlers should return 0 for
 * ``not me'' or 1 (``I took care of it'').  intr_establish() inserts a
 * handler into the list.  The handler is called with its (single)
 * argument, or with a pointer to a clockframe if ih_arg is NULL.
 */
struct intrhand {
	int			(*ih_fun)(void *);
	void			*ih_arg;
	/* if we have to take the biglock, we interpose a wrapper
	 * and need to save the original function and arg */
	int			(*ih_realfun)(void *);
	void			*ih_realarg;
	short			ih_number;	/* interrupt number */
						/* the H/W provides */
	char			ih_pil;		/* interrupt priority */
	struct intrhand		*ih_next;	/* global list */
	struct intrhand		*ih_pending;	/* interrupt queued */
	volatile uint64_t	*ih_map;	/* Interrupt map reg */
	volatile uint64_t	*ih_clr;	/* clear interrupt reg */
	void			(*ih_ack)(struct intrhand *); /* ack interrupt function */
	bus_space_tag_t		ih_bus;		/* parent bus */
	struct evcnt		ih_cnt;		/* counter for vmstat */
	uint32_t		ih_ivec;
	char			ih_name[32];	/* name for the above */
};
extern struct intrhand *intrhand[];
extern struct intrhand *intrlev[MAXINTNUM];

void	intr_establish(int level, bool mpsafe, struct intrhand *);
void	*sparc_softintr_establish(int, int (*)(void *), void *);
void	sparc_softintr_schedule(void *);
void	sparc_softintr_disestablish(void *);
struct intrhand *intrhand_alloc(void);

/* cpu.c */
int	cpu_myid(void);

/* disksubr.c */
struct dkbad;
int isbad(struct dkbad *bt, int, int, int);
/* machdep.c */
void *	reserve_dumppages(void *);
/* clock.c */
struct timeval;
int	tickintr(void *);	/* level 10/14 (tick) interrupt code */
int	stickintr(void *);	/* system tick interrupt code */
int	stick2eintr(void *);	/* system tick interrupt code */
int	clockintr(void *);	/* level 10 (clock) interrupt code */
int	statintr(void *);	/* level 14 (statclock) interrupt code */
int	schedintr(void *);	/* level 10 (schedclock) interrupt code */
void	tickintr_establish(int, int (*)(void *));
void	stickintr_establish(int, int (*)(void *));
void	stick2eintr_establish(int, int (*)(void *));

/* locore.s */
struct fpstate64;
void	savefpstate(struct fpstate64 *);
void	loadfpstate(struct fpstate64 *);
void	clearfpstate(void);
uint64_t	probeget(paddr_t, int, int);
int	probeset(paddr_t, int, int, uint64_t);
void	setcputyp(int);

#define	 write_all_windows() __asm volatile("flushw" : : )
#define	 write_user_windows() __asm volatile("flushw" : : )

struct pcb;
void	snapshot(struct pcb *);
struct frame *getfp(void);
void	switchtoctx_us(int);
void	switchtoctx_usiii(int);
void	next_tick(long);
void	next_stick(long);
void	next_stick_init(void);
/* trap.c */
void	cpu_vmspace_exec(struct lwp *, vaddr_t, vaddr_t);
int	rwindow_save(struct lwp *);
/* cons.c */
int	cnrom(void);
/* zs.c */
void zsconsole(struct tty *, int, int, void (**)(struct tty *, int));
/* fb.c */
void	fb_unblank(void);
/* kgdb_stub.c */
#ifdef KGDB
void kgdb_attach(int (*)(void *), void (*)(void *, int), void *);
void kgdb_connect(int);
void kgdb_panic(void);
#endif
/* emul.c */
int	fixalign(struct lwp *, struct trapframe64 *);
int	emulinstr(vaddr_t, struct trapframe64 *);

#endif /* _KERNEL */
#endif /* _CPU_H_ */