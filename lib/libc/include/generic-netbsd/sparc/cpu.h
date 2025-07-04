/*	$NetBSD: cpu.h,v 1.110.4.1 2023/08/09 17:42:02 martin Exp $ */

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

/*
 * Exported definitions unique to SPARC cpu support.
 */

/*
 * Sun-4 and Sun-4c virtual address cache.
 *
 * Sun-4 virtual caches come in two flavors, write-through (Sun-4c)
 * and write-back (Sun-4).  The write-back caches are much faster
 * but require a bit more care.
 *
 * This is exported via sysctl so be careful changing it.
 */
enum vactype { VAC_UNKNOWN, VAC_NONE, VAC_WRITETHROUGH, VAC_WRITEBACK };

/*
 * Cache control information.
 *
 * This is exported via sysctl so be careful changing it.
 */

struct cacheinfo {
	int	c_totalsize;		/* total size, in bytes */
					/* if split, MAX(icache,dcache) */
	int	c_enabled;		/* true => cache is enabled */
	int	c_hwflush;		/* true => have hardware flush */
	int	c_linesize;		/* line size, in bytes */
					/* if split, MIN(icache,dcache) */
	int	c_l2linesize;		/* log2(linesize) */
	int	c_nlines;		/* precomputed # of lines to flush */
	int	c_physical;		/* true => cache has physical
						   address tags */
	int 	c_associativity;	/* # of "buckets" in cache line */
	int 	c_split;		/* true => cache is split */

	int 	ic_totalsize;		/* instruction cache */
	int 	ic_enabled;
	int 	ic_linesize;
	int 	ic_l2linesize;
	int 	ic_nlines;
	int 	ic_associativity;

	int 	dc_totalsize;		/* data cache */
	int 	dc_enabled;
	int 	dc_linesize;
	int 	dc_l2linesize;
	int 	dc_nlines;
	int 	dc_associativity;

	int	ec_totalsize;		/* external cache info */
	int 	ec_enabled;
	int	ec_linesize;
	int	ec_l2linesize;
	int 	ec_nlines;
	int 	ec_associativity;

	enum vactype	c_vactype;

	int	c_flags;
#define CACHE_PAGETABLES	0x1	/* caching pagetables OK on (sun4m) */
#define CACHE_TRAPPAGEBUG	0x2	/* trap page can't be cached (sun4) */
#define CACHE_MANDATORY		0x4	/* if cache is on, don't use
					   uncached access */
};

/* Things needed by crash or the kernel */
#if defined(_KERNEL) || defined(_KMEMUSER)

#if defined(_KERNEL_OPT)
#include "opt_gprof.h"
#include "opt_multiprocessor.h"
#include "opt_lockdebug.h"
#include "opt_sparc_arch.h"
#endif

#include <sys/cpu_data.h>
#include <sys/evcnt.h>

#include <machine/intr.h>
#include <machine/psl.h>

#if defined(_KERNEL)
#include <sparc/sparc/cpuvar.h>
#include <sparc/sparc/intreg.h>
#endif

struct trapframe;

/*
 * Message structure for Inter Processor Communication in MP systems
 */
struct xpmsg {
	volatile int tag;
#define	XPMSG15_PAUSECPU	1
#define	XPMSG_FUNC		4
#define	XPMSG_FTRP		5

	volatile union {
		/*
		 * Cross call: ask to run (*func)(arg0,arg1,arg2)
		 * or (*trap)(arg0,arg1,arg2). `trap' should be the
		 * address of a `fast trap' handler that executes in
		 * the trap window (see locore.s).
		 */
		struct xpmsg_func {
			void	(*func)(int, int, int);
			void	(*trap)(int, int, int);
			int	arg0;
			int	arg1;
			int	arg2;
		} xpmsg_func;
	} u;
	volatile int	received;
	volatile int	complete;
};

/*
 * The cpuinfo structure. This structure maintains information about one
 * currently installed CPU (there may be several of these if the machine
 * supports multiple CPUs, as on some Sun4m architectures). The information
 * in this structure supersedes the old "cpumod", "mmumod", and similar
 * fields.
 */

struct cpu_info {
	/*
	 * Primary Inter-processor message area.  Keep this aligned
	 * to a cache line boundary if possible, as the structure
	 * itself is one or less (32/64 byte) cache-line.
	 */
	struct xpmsg	msg __aligned(64);

	/* Scheduler flags */
	int	ci_want_ast;
	int	ci_want_resched;

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

	int		ci_cpuid;	/* CPU index (see cpus[] array) */

	/* Context administration */
	int		*ctx_tbl;	/* [4m] SRMMU-edible context table */
	paddr_t		ctx_tbl_pa;	/* [4m] ctx table physical address */

	/* Cache information */
	struct cacheinfo	cacheinfo;	/* see above */

	/* various flags to workaround anomalies in chips */
	volatile int	flags;		/* see CPUFLG_xxx, below */

	/* Per processor counter register (sun4m only) */
	volatile struct counter_4m	*counterreg_4m;

	/* Per processor interrupt mask register (sun4m only) */
	volatile struct icr_pi	*intreg_4m;
	/*
	 * Send a IPI to (cpi).  For Ross cpus we need to read
	 * the pending register to avoid a hardware bug.
	 */
#define raise_ipi(cpi,lvl)	do {			\
	volatile int x;						\
	(cpi)->intreg_4m->pi_set = PINTR_SINTRLEV(lvl);	\
	x = (cpi)->intreg_4m->pi_pend; __USE(x);	\
} while (0)

	int		sun4_mmu3l;	/* [4]: 3-level MMU present */
#if defined(SUN4_MMU3L)
#define HASSUN4_MMU3L	(cpuinfo.sun4_mmu3l)
#else
#define HASSUN4_MMU3L	(0)
#endif
	int		ci_idepth;		/* Interrupt depth */

	/*
	 * The following pointers point to processes that are somehow
	 * associated with this CPU--running on it, using its FPU,
	 * etc.
	 */
	struct	lwp	*ci_curlwp;		/* CPU owner */
	struct	lwp	*ci_onproc;		/* current user LWP / kthread */
	struct	lwp 	*fplwp;			/* FPU owner */

	int		ci_mtx_count;
	int		ci_mtx_oldspl;

	/*
	 * Idle PCB and Interrupt stack;
	 */
	void		*eintstack;		/* End of interrupt stack */
#define INT_STACK_SIZE	(128 * 128)		/* 128 128-byte stack frames */
	void		*redzone;		/* DEBUG: stack red zone */
#define REDSIZE		(8*96)			/* some room for bouncing */

	struct	pcb	*curpcb;		/* CPU's PCB & kernel stack */

	/* locore defined: */
	void	(*get_syncflt)(void);		/* Not C-callable */
	int	(*get_asyncflt)(u_int *, u_int *);

	/* Synchronous Fault Status; temporary storage */
	struct {
		int	sfsr;
		int	sfva;
	} syncfltdump;

	/*
	 * Cache handling functions.
	 * Most cache flush function come in two flavours: one that
	 * acts only on the CPU it executes on, and another that
	 * uses inter-processor signals to flush the cache on
	 * all processor modules.
	 * The `ft_' versions are fast trap cache flush handlers.
	 */
	void	(*cache_flush)(void *, u_int);
	void	(*vcache_flush_page)(int, int);
	void	(*sp_vcache_flush_page)(int, int);
	void	(*ft_vcache_flush_page)(int, int);
	void	(*vcache_flush_segment)(int, int, int);
	void	(*sp_vcache_flush_segment)(int, int, int);
	void	(*ft_vcache_flush_segment)(int, int, int);
	void	(*vcache_flush_region)(int, int);
	void	(*sp_vcache_flush_region)(int, int);
	void	(*ft_vcache_flush_region)(int, int);
	void	(*vcache_flush_context)(int);
	void	(*sp_vcache_flush_context)(int);
	void	(*ft_vcache_flush_context)(int);

	/* The are helpers for (*cache_flush)() */
	void	(*sp_vcache_flush_range)(int, int, int);
	void	(*ft_vcache_flush_range)(int, int, int);

	void	(*pcache_flush_page)(paddr_t, int);
	void	(*pure_vcache_flush)(void);
	void	(*cache_flush_all)(void);

	/* Support for hardware-assisted page clear/copy */
	void	(*zero_page)(paddr_t);
	void	(*copy_page)(paddr_t, paddr_t);

	/* Virtual addresses for use in pmap copy_page/zero_page */
	void *	vpage[2];
	int	*vpage_pte[2];		/* pte location of vpage[] */

	void	(*cache_enable)(void);

	int	cpu_type;	/* Type: see CPUTYP_xxx below */

	/* Inter-processor message area (high priority but used infrequently) */
	struct xpmsg	msg_lev15;

	/* CPU information */
	int		node;		/* PROM node for this CPU */
	int		mid;		/* Module ID for MP systems */
	int		mbus;		/* 1 if CPU is on MBus */
	int		mxcc;		/* 1 if a MBus-level MXCC is present */
	const char	*cpu_longname;	/* CPU model */
	int		cpu_impl;	/* CPU implementation code */
	int		cpu_vers;	/* CPU version code */
	int		mmu_impl;	/* MMU implementation code */
	int		mmu_vers;	/* MMU version code */
	int		master;		/* 1 if this is bootup CPU */

	vaddr_t		mailbox;	/* VA of CPU's mailbox */

	int		mmu_ncontext;	/* Number of contexts supported */
	int		mmu_nregion; 	/* Number of regions supported */
	int		mmu_nsegment;	/* [4/4c] Segments */
	int		mmu_npmeg;	/* [4/4c] Pmegs */

/* XXX - we currently don't actually use the following */
	int		arch;		/* Architecture: CPU_SUN4x */
	int		class;		/* Class: SuperSPARC, microSPARC... */
	int		classlvl;	/* Iteration in class: 1, 2, etc. */
	int		classsublvl;	/* stepping in class (version) */

	int		hz;		/* Clock speed */

	/* FPU information */
	int		fpupresent;	/* true if FPU is present */
	int		fpuvers;	/* FPU revision */
	const char	*fpu_name;	/* FPU model */
	char		fpu_namebuf[32];/* Buffer for FPU name, if necessary */

	/* XXX */
	volatile void	*ci_ddb_regs;		/* DDB regs */

	/*
	 * The following are function pointers to do interesting CPU-dependent
	 * things without having to do type-tests all the time
	 */

	/* bootup things: access to physical memory */
	u_int	(*read_physmem)(u_int addr, int space);
	void	(*write_physmem)(u_int addr, u_int data);
	void	(*cache_tablewalks)(void);
	void	(*mmu_enable)(void);
	void	(*hotfix)(struct cpu_info *);


#if 0
	/* hardware-assisted block operation routines */
	void		(*hwbcopy)(const void *from, void *to, size_t len);
	void		(*hwbzero)(void *buf, size_t len);

	/* routine to clear mbus-sbus buffers */
	void		(*mbusflush)(void);
#endif

	/*
	 * Memory error handler; parity errors, unhandled NMIs and other
	 * unrecoverable faults end up here.
	 */
	void		(*memerr)(unsigned, u_int, u_int, struct trapframe *);
	void		(*idlespin)(void);
	/* Module Control Registers */
	/*bus_space_handle_t*/ long ci_mbusport;
	/*bus_space_handle_t*/ long ci_mxccregs;

	u_int	ci_tt;			/* Last trap (if tracing) */

	/*
	 * Start/End VA's of this cpu_info region; we upload the other pages
	 * in this region that aren't part of the cpu_info to uvm.
	 */
	vaddr_t	ci_free_sva1, ci_free_eva1, ci_free_sva2, ci_free_eva2;

	struct evcnt ci_savefpstate;
	struct evcnt ci_savefpstate_null;
	struct evcnt ci_xpmsg_mutex_fail;
	struct evcnt ci_xpmsg_mutex_fail_call;
	struct evcnt ci_xpmsg_mutex_not_held;
	struct evcnt ci_xpmsg_bogus;
	struct evcnt ci_intrcnt[16];
	struct evcnt ci_sintrcnt[16];

	struct cpu_data ci_data;	/* MI per-cpu data */

#if defined(GPROF) && defined(MULTIPROCESSOR)
	struct gmonparam *ci_gmon;	/* MI per-cpu GPROF */
#endif
};

#endif /* _KERNEL || _KMEMUSER */

/* Kernel only things. */
#if defined(_KERNEL)

#include <sys/mutex.h>

/*
 * definitions of cpu-dependent requirements
 * referenced in generic code
 */
#define	cpuinfo			(*(struct cpu_info *)CPUINFO_VA)
#define	curcpu()		(cpuinfo.ci_self)
#define	curlwp			(cpuinfo.ci_curlwp)
#define	CPU_IS_PRIMARY(ci)	((ci)->master)

#define	cpu_number()		(cpuinfo.ci_cpuid)

void	cpu_proc_fork(struct proc *, struct proc *);

#if defined(MULTIPROCESSOR)
void	cpu_boot_secondary_processors(void);
#endif

/*
 * Arguments to hardclock, softclock and statclock encapsulate the
 * previous machine state in an opaque clockframe.  The ipl is here
 * as well for strayintr (see locore.s:interrupt and intr.c:strayintr).
 * Note that CLKF_INTR is valid only if CLKF_USERMODE is false.
 */
struct clockframe {
	u_int	psr;		/* psr before interrupt, excluding PSR_ET */
	u_int	pc;		/* pc at interrupt */
	u_int	npc;		/* npc at interrupt */
	u_int	ipl;		/* actual interrupt priority level */
	u_int	fp;		/* %fp at interrupt */
};
typedef struct clockframe clockframe;

extern int eintstack[];

#define	CLKF_USERMODE(framep)	(((framep)->psr & PSR_PS) == 0)
#define	CLKF_LOPRI(framep,n)	(((framep)->psr & PSR_PIL) < (n) << 8)
#define	CLKF_PC(framep)		((framep)->pc)
#if defined(MULTIPROCESSOR)
#define	CLKF_INTR(framep)						\
	((framep)->fp > (u_int)cpuinfo.eintstack - INT_STACK_SIZE &&	\
	 (framep)->fp < (u_int)cpuinfo.eintstack)
#else
#define	CLKF_INTR(framep)	((framep)->fp < (u_int)eintstack)
#endif

void	sparc_softintr_init(void);

/*
 * Preempt the current process on the target CPU if in interrupt from
 * user mode, or after the current trap/syscall if in system mode.
 */
#define cpu_need_resched(ci, l, flags) do {				\
	__USE(flags);							\
	(ci)->ci_want_ast = 1;						\
									\
	/* Just interrupt the target CPU, so it can notice its AST */	\
	if ((flags & RESCHED_REMOTE) != 0)				\
		XCALL0(sparc_noop, 1U << (ci)->ci_cpuid);		\
} while (/*CONSTCOND*/0)

/*
 * Give a profiling tick to the current process when the user profiling
 * buffer pages are invalid.  On the sparc, request an ast to send us
 * through trap(), marking the proc as needing a profiling tick.
 */
#define	cpu_need_proftick(l)	((l)->l_pflag |= LP_OWEUPC, cpuinfo.ci_want_ast = 1)

/*
 * Notify the current process (p) that it has a signal pending,
 * process as soon as possible.
 */
#define cpu_signotify(l) do {						\
	(l)->l_cpu->ci_want_ast = 1;					\
									\
	/* Just interrupt the target CPU, so it can notice its AST */	\
	if ((l)->l_cpu->ci_cpuid != cpu_number())			\
		XCALL0(sparc_noop, 1U << (l)->l_cpu->ci_cpuid);		\
} while (/*CONSTCOND*/0)

/* CPU architecture version */
extern int cpu_arch;

/* Number of CPUs in the system */
extern int sparc_ncpus;

/* Provide %pc of a lwp */
#define LWP_PC(l)       ((l)->l_md.md_tf->tf_pc)

/* Hardware cross-call mutex */
extern kmutex_t xpmsg_mutex;

/*
 * Interrupt handler chains.  Interrupt handlers should return 0 for
 * ``not me'' or 1 (``I took care of it'').  intr_establish() inserts a
 * handler into the list.  The handler is called with its (single)
 * argument, or with a pointer to a clockframe if ih_arg is NULL.
 *
 * realfun/realarg are used to chain callers, usually with the
 * biglock wrapper.
 */
extern struct intrhand {
	int	(*ih_fun)(void *);
	void	*ih_arg;
	struct	intrhand *ih_next;
	int	ih_classipl;
	int	(*ih_realfun)(void *);
	void	*ih_realarg;
} *intrhand[15];

void	intr_establish(int, int, struct intrhand *, void (*)(void), bool);
void	intr_disestablish(int, struct intrhand *);

void	intr_lock_kernel(void);
void	intr_unlock_kernel(void);

/* disksubr.c */
struct dkbad;
int isbad(struct dkbad *, int, int, int);

/* machdep.c */
int	ldcontrolb(void *);
void *	reserve_dumppages(void *);
void	wcopy(const void *, void *, u_int);
void	wzero(void *, u_int);

/* clock.c */
struct timeval;
void	lo_microtime(struct timeval *);
void	schedintr(void *);

/* locore.s */
struct fpstate;
void	ipi_savefpstate(struct fpstate *);
void	savefpstate(struct fpstate *);
void	loadfpstate(struct fpstate *);
int	probeget(void *, int);
void	write_all_windows(void);
void	write_user_windows(void);
void 	lwp_trampoline(void);
struct pcb;
void	snapshot(struct pcb *);
struct frame *getfp(void);
int	xldcontrolb(void *, struct pcb *);
void	copywords(const void *, void *, size_t);
void	qcopy(const void *, void *, size_t);
void	qzero(void *, size_t);

/* trap.c */
void	cpu_vmspace_exec(struct lwp *, vaddr_t, vaddr_t);
int	rwindow_save(struct lwp *);

/* cons.c */
int	cnrom(void);

/* zs.c */
void zsconsole(struct tty *, int, int, void (**)(struct tty *, int));
#ifdef KGDB
void zs_kgdb_init(void);
#endif

/* fb.c */
void	fb_unblank(void);

/* kgdb_stub.c */
#ifdef KGDB
void kgdb_attach(int (*)(void *), void (*)(void *, int), void *);
void kgdb_connect(int);
void kgdb_panic(void);
#endif

/* emul.c */
struct trapframe;
int fixalign(struct lwp *, struct trapframe *, void **);
int emulinstr(int, struct trapframe *);

/* cpu.c */
void mp_pause_cpus(void);
void mp_resume_cpus(void);
void mp_halt_cpus(void);
#ifdef DDB
void mp_pause_cpus_ddb(void);
void mp_resume_cpus_ddb(void);
#endif

/* intr.c */
u_int setitr(u_int);
u_int getitr(void);


/*
 *
 * The SPARC has a Trap Base Register (TBR) which holds the upper 20 bits
 * of the trap vector table.  The next eight bits are supplied by the
 * hardware when the trap occurs, and the bottom four bits are always
 * zero (so that we can shove up to 16 bytes of executable code---exactly
 * four instructions---into each trap vector).
 *
 * The hardware allocates half the trap vectors to hardware and half to
 * software.
 *
 * Traps have priorities assigned (lower number => higher priority).
 */

struct trapvec {
	int	tv_instr[4];		/* the four instructions */
};

extern struct trapvec *trapbase;	/* the 256 vectors */

#endif /* _KERNEL */
#endif /* _CPU_H_ */