/*	$NetBSD: cpu.h,v 1.123 2022/11/15 12:43:14 macallan Exp $	*/

/*
 * Copyright (C) 1999 Wolfgang Solfrank.
 * Copyright (C) 1999 TooLs GmbH.
 * Copyright (C) 1995-1997 Wolfgang Solfrank.
 * Copyright (C) 1995-1997 TooLs GmbH.
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

#ifndef	_POWERPC_CPU_H_
#define	_POWERPC_CPU_H_

struct cache_info {
	int dcache_size;
	int dcache_line_size;
	int icache_size;
	int icache_line_size;
};

#if defined(_KERNEL) || defined(_KMEMUSER)
#if defined(_KERNEL_OPT)
#include "opt_gprof.h"
#include "opt_modular.h"
#include "opt_multiprocessor.h"
#include "opt_ppcarch.h"
#include "opt_ppcopts.h"
#endif

#ifdef _KERNEL
#include <sys/intr.h>
#include <sys/device_if.h>
#include <sys/evcnt.h>
#include <sys/param.h>
#include <sys/kernel.h>
#endif

#include <sys/cpu_data.h>

#ifdef _KERNEL
#define	CI_SAVETEMP	(0*CPUSAVE_LEN)
#define	CI_SAVEDDB	(1*CPUSAVE_LEN)
#define	CI_SAVEIPKDB	(2*CPUSAVE_LEN)	/* obsolete */
#define	CI_SAVEMMU	(3*CPUSAVE_LEN)
#define	CI_SAVEMAX	(4*CPUSAVE_LEN)
#define	CPUSAVE_LEN	8
#if defined(PPC_BOOKE) && !defined(MODULAR) && !defined(_MODULE)
#define	CPUSAVE_SIZE	128
#else
#define	CPUSAVE_SIZE	(CI_SAVEMAX*CPUSAVE_LEN)
CTASSERT(CPUSAVE_SIZE >= 128);
#endif
#define	CPUSAVE_R28	0		/* where r28 gets saved */
#define	CPUSAVE_R29	1		/* where r29 gets saved */
#define	CPUSAVE_R30	2		/* where r30 gets saved */
#define	CPUSAVE_R31	3		/* where r31 gets saved */
#define	CPUSAVE_DEAR	4		/* where IBM4XX SPR_DEAR gets saved */
#define	CPUSAVE_DAR	4		/* where OEA SPR_DAR gets saved */
#define	CPUSAVE_ESR	5		/* where IBM4XX SPR_ESR gets saved */
#define	CPUSAVE_DSISR	5		/* where OEA SPR_DSISR gets saved */
#define	CPUSAVE_SRR0	6		/* where SRR0 gets saved */
#define	CPUSAVE_SRR1	7		/* where SRR1 gets saved */
#endif /* _KERNEL */

struct cpu_info {
	struct cpu_data ci_data;	/* MI per-cpu data */
#ifdef _KERNEL
	device_t ci_dev;		/* device of corresponding cpu */
	struct cpu_softc *ci_softc;	/* private cpu info */
	struct lwp *ci_curlwp;		/* current owner of the processor */
	struct lwp *ci_onproc;		/* current user LWP / kthread */
	struct pcb *ci_curpcb;
	struct pmap *ci_curpm;
#if defined(PPC_OEA) || defined(PPC_OEA601) || defined(PPC_OEA64) || \
    defined(PPC_OEA64_BRIDGE) || defined(MODULAR) || defined(_MODULE)
	void *ci_battable;		/* BAT table in use by this CPU */
#endif
	struct lwp *ci_softlwps[SOFTINT_COUNT];
	int ci_cpuid;			/* from SPR_PIR */

	int ci_want_resched;
	volatile uint64_t ci_lastintr;
	volatile u_long ci_lasttb;
	volatile int ci_tickspending;
	volatile int ci_cpl;
	volatile int ci_iactive;
	volatile int ci_idepth;
	union {
#if !defined(PPC_BOOKE) && !defined(_MODULE)
		volatile imask_t un1_ipending;
#define	ci_ipending	ci_un1.un1_ipending
#endif
		uint64_t un1_pad64;
	} ci_un1;
	volatile uint32_t ci_pending_ipis;
	int ci_mtx_oldspl;
	int ci_mtx_count;
#if defined(PPC_IBM4XX) || \
    ((defined(MODULAR) || defined(_MODULE)) && !defined(_LP64))
	char *ci_intstk;
#endif

	register_t ci_savearea[CPUSAVE_SIZE];
#if defined(PPC_BOOKE) || \
    ((defined(MODULAR) || defined(_MODULE)) && !defined(_LP64))
	uint32_t ci_pmap_asid_cur;
	union pmap_segtab *ci_pmap_segtabs[2];
#define	ci_pmap_kern_segtab	ci_pmap_segtabs[0]
#define	ci_pmap_user_segtab	ci_pmap_segtabs[1]
	struct pmap_tlb_info *ci_tlb_info;
#endif /* PPC_BOOKE || ((MODULAR || _MODULE) && !_LP64) */
	struct cache_info ci_ci;		
	void *ci_sysmon_cookie;
	void (*ci_idlespin)(void);
	uint32_t ci_khz;
	struct evcnt ci_ev_clock;	/* clock intrs */
	struct evcnt ci_ev_statclock; 	/* stat clock */
	struct evcnt ci_ev_traps;	/* calls to trap() */
	struct evcnt ci_ev_kdsi;	/* kernel DSI traps */
	struct evcnt ci_ev_udsi;	/* user DSI traps */
	struct evcnt ci_ev_udsi_fatal;	/* user DSI trap failures */
	struct evcnt ci_ev_kisi;	/* kernel ISI traps */
	struct evcnt ci_ev_isi;		/* user ISI traps */
	struct evcnt ci_ev_isi_fatal;	/* user ISI trap failures */
	struct evcnt ci_ev_pgm;		/* user PGM traps */
	struct evcnt ci_ev_debug;	/* user debug traps */
	struct evcnt ci_ev_fpu;		/* FPU traps */
	struct evcnt ci_ev_fpusw;	/* FPU context switch */
	struct evcnt ci_ev_ali;		/* Alignment traps */
	struct evcnt ci_ev_ali_fatal;	/* Alignment fatal trap */
	struct evcnt ci_ev_scalls;	/* system call traps */
	struct evcnt ci_ev_vec;		/* Altivec traps */
	struct evcnt ci_ev_vecsw;	/* Altivec context switches */
	struct evcnt ci_ev_umchk;	/* user MCHK events */
	struct evcnt ci_ev_ipi;		/* IPIs received */
	struct evcnt ci_ev_tlbmiss_soft; /* tlb miss (no trap) */
	struct evcnt ci_ev_dtlbmiss_hard; /* data tlb miss (trap) */
	struct evcnt ci_ev_itlbmiss_hard; /* instruction tlb miss (trap) */
#if defined(GPROF) && defined(MULTIPROCESSOR)
	struct gmonparam *ci_gmon;	/* MI per-cpu GPROF */
#endif
#endif /* _KERNEL */
};
#endif /* _KERNEL || _KMEMUSER */

#ifdef _KERNEL

#if defined(MULTIPROCESSOR) && !defined(_MODULE)
struct cpu_hatch_data {
	int hatch_running;
	device_t hatch_self;
	struct cpu_info *hatch_ci;
	uint32_t hatch_tbu;
	uint32_t hatch_tbl;
#if defined(PPC_OEA64_BRIDGE) || defined (_ARCH_PPC64)
	uint64_t hatch_hid0;
	uint64_t hatch_hid1;
	uint64_t hatch_hid4;
	uint64_t hatch_hid5;
#else
	uint32_t hatch_hid0;
#endif
	uint32_t hatch_pir;
#if defined(PPC_OEA) || defined(PPC_OEA64_BRIDGE)
	uintptr_t hatch_asr;
	uintptr_t hatch_sdr1;
	uint32_t hatch_sr[16];
	uintptr_t hatch_ibatu[8], hatch_ibatl[8];
	uintptr_t hatch_dbatu[8], hatch_dbatl[8];
#endif
#if defined(PPC_BOOKE)
	vaddr_t hatch_sp;
	u_int hatch_tlbidx;
#endif
};

struct cpuset_info {
	kcpuset_t *cpus_running;
	kcpuset_t *cpus_hatched;
	kcpuset_t *cpus_paused;
	kcpuset_t *cpus_resumed;
	kcpuset_t *cpus_halted;
};

extern struct cpuset_info cpuset_info;
#endif /* MULTIPROCESSOR && !_MODULE */

#if defined(MULTIPROCESSOR) || defined(_MODULE)
#define	cpu_number()		(curcpu()->ci_index + 0)

#define CPU_IS_PRIMARY(ci)	((ci)->ci_cpuid == 0)
#define CPU_INFO_ITERATOR	int
#define CPU_INFO_FOREACH(cii, ci)				\
	cii = 0, ci = &cpu_info[0]; cii < (ncpu ? ncpu : 1); cii++, ci++

#else
#define cpu_number()		0

#define CPU_IS_PRIMARY(ci)	true
#define CPU_INFO_ITERATOR	int
#define CPU_INFO_FOREACH(cii, ci)				\
	(void)cii, ci = curcpu(); ci != NULL; ci = NULL

#endif /* MULTIPROCESSOR || _MODULE */

extern struct cpu_info cpu_info[];

static __inline struct cpu_info * curcpu(void) __pure;
static __inline __always_inline struct cpu_info *
curcpu(void)
{
	struct cpu_info *ci;

	__asm volatile ("mfsprg0 %0" : "=r"(ci));
	return ci;
}

register struct lwp *powerpc_curlwp __asm("r13");
#define	curlwp			powerpc_curlwp
#define curpcb			(curcpu()->ci_curpcb)
#define curpm			(curcpu()->ci_curpm)

static __inline register_t
mfmsr(void)
{
	register_t msr;

	__asm volatile ("mfmsr %0" : "=r"(msr));
	return msr;
}

static __inline void
mtmsr(register_t msr)
{
	//KASSERT(msr & PSL_CE);
	//KASSERT(msr & PSL_DE);
	__asm volatile ("mtmsr %0" : : "r"(msr));
}

#if !defined(_MODULE)
static __inline uint32_t
mftbl(void)
{
	uint32_t tbl;

	__asm volatile (
#ifdef PPC_IBM403
	"	mftblo %[tbl]"		"\n"
#elif defined(PPC_BOOKE)
	"	mfspr %[tbl],268"	"\n"
#else
	"	mftbl %[tbl]"		"\n"
#endif
	: [tbl] "=r" (tbl));

	return tbl;
}

static __inline uint64_t
mftb(void)
{
	uint64_t tb;

#ifdef _ARCH_PPC64
	__asm volatile ("mftb %0" : "=r"(tb));
#else
	int tmp;

	__asm volatile (
#ifdef PPC_IBM403
	"1:	mftbhi %[tb]"		"\n"
	"	mftblo %L[tb]"		"\n"
	"	mftbhi %[tmp]"		"\n"
#elif defined(PPC_BOOKE)
	"1:	mfspr %[tb],269"	"\n"
	"	mfspr %L[tb],268"	"\n"
	"	mfspr %[tmp],269"	"\n"
#else
	"1:	mftbu %[tb]"		"\n"
	"	mftb %L[tb]"		"\n"
	"	mftbu %[tmp]"		"\n"
#endif
	"	cmplw %[tb],%[tmp]"	"\n"
	"	bne- 1b"		"\n"
	    : [tb] "=r" (tb), [tmp] "=r"(tmp)
	    :: "cr0");
#endif

	return tb;
}

static __inline uint32_t
mfrtcl(void)
{
	uint32_t rtcl;

	__asm volatile ("mfrtcl %0" : "=r"(rtcl));
	return rtcl;
}

static __inline void
mfrtc(uint32_t *rtcp)
{
	uint32_t tmp;

	__asm volatile (
	"1:	mfrtcu	%[rtcu]"	"\n"
	"	mfrtcl	%[rtcl]"	"\n"
	"	mfrtcu	%[tmp]"		"\n"
	"	cmplw	%[rtcu],%[tmp]"	"\n"
	"	bne-	1b"
	    : [rtcu] "=r"(rtcp[0]), [rtcl] "=r"(rtcp[1]), [tmp] "=r"(tmp)
	    :: "cr0");
}

static __inline uint64_t
rtc_nanosecs(void)
{
    /* 
     * 601 RTC/DEC registers share clock of 7.8125 MHz, 128 ns per tick.
     * DEC has max of 25 bits, FFFFFF => 2.14748352 seconds.
     * RTCU is seconds, 32 bits.
     * RTCL is nano-seconds, 23 bit counter from 0 - 999,999,872 (999,999,999 - 128 ns)
     */
    uint64_t cycles;
    uint32_t tmp[2];

    mfrtc(tmp);

    cycles = tmp[0] * 1000000000;
    cycles += (tmp[1] >> 7);

    return cycles;
}
#endif /* !_MODULE */

static __inline uint32_t
mfpvr(void)
{
	uint32_t pvr;

	__asm volatile ("mfpvr %0" : "=r"(pvr));
	return (pvr);
}

#ifdef _MODULE
extern const char __CPU_MAXNUM;
/*
 * Make with 0xffff to force a R_PPC_ADDR16_LO without the
 * corresponding R_PPC_ADDR16_HI relocation.
 */
#define	CPU_MAXNUM	(((uintptr_t)&__CPU_MAXNUM)&0xffff)
#endif /* _MODULE */

#if !defined(_MODULE)
extern char *booted_kernel;
extern int powersave;
extern int cpu_timebase;
extern int cpu_printfataltraps;

struct cpu_info *
	cpu_attach_common(device_t, int);
void	cpu_setup(device_t, struct cpu_info *);
void	cpu_identify(char *, size_t);
void	cpu_probe_cache(void);

void	dcache_wb_page(vaddr_t);
void	dcache_wbinv_page(vaddr_t);
void	dcache_inv_page(vaddr_t);
void	dcache_zero_page(vaddr_t);
void	icache_inv_page(vaddr_t);
void	dcache_wb(vaddr_t, vsize_t);
void	dcache_wbinv(vaddr_t, vsize_t);
void	dcache_inv(vaddr_t, vsize_t);
void	icache_inv(vaddr_t, vsize_t);

void *	mapiodev(paddr_t, psize_t, bool);
void	unmapiodev(vaddr_t, vsize_t);

int	emulate_mxmsr(struct lwp *, struct trapframe *, uint32_t);

#ifdef MULTIPROCESSOR
int	md_setup_trampoline(volatile struct cpu_hatch_data *,
	    struct cpu_info *);
void	md_presync_timebase(volatile struct cpu_hatch_data *);
void	md_start_timebase(volatile struct cpu_hatch_data *);
void	md_sync_timebase(volatile struct cpu_hatch_data *);
void	md_setup_interrupts(void);
int	cpu_spinup(device_t, struct cpu_info *);
register_t
	cpu_hatch(void);
void	cpu_spinup_trampoline(void);
void	cpu_boot_secondary_processors(void);
void	cpu_halt(void);
void	cpu_halt_others(void);
void	cpu_pause(struct trapframe *);
void	cpu_pause_others(void);
void	cpu_resume(cpuid_t);
void	cpu_resume_others(void);
int	cpu_is_paused(int);
void	cpu_debug_dump(void);
#endif /* MULTIPROCESSOR */
#endif /* !_MODULE */

#define	cpu_proc_fork(p1, p2)

#ifndef __HIDE_DELAY
#define	DELAY(n)		delay(n)
void	delay(unsigned int);
#endif /* __HIDE_DELAY */

#define	CLKF_USERMODE(cf)	cpu_clkf_usermode(cf)
#define	CLKF_PC(cf)		cpu_clkf_pc(cf)
#define	CLKF_INTR(cf)		cpu_clkf_intr(cf)

bool	cpu_clkf_usermode(const struct clockframe *);
vaddr_t	cpu_clkf_pc(const struct clockframe *);
bool	cpu_clkf_intr(const struct clockframe *);

#define	LWP_PC(l)		cpu_lwp_pc(l)

vaddr_t	cpu_lwp_pc(struct lwp *);

void	cpu_ast(struct lwp *, struct cpu_info *);
void *	cpu_uarea_alloc(bool);
bool	cpu_uarea_free(void *);
void	cpu_signotify(struct lwp *);
void	cpu_need_proftick(struct lwp *);

void	cpu_fixup_stubs(void);

#if !defined(PPC_IBM4XX) && !defined(PPC_BOOKE) && !defined(_MODULE)
int	cpu_get_dfs(void);
void	cpu_set_dfs(int);

void	oea_init(void (*)(void));
void	oea_startup(const char *);
void	oea_dumpsys(void);
void	oea_install_extint(void (*)(void));
paddr_t	kvtop(void *);

extern paddr_t msgbuf_paddr;
extern int cpu_altivec;
#endif

#ifdef PPC_NO_UNALIGNED
bool	fix_unaligned(struct trapframe *, ksiginfo_t *);
#endif

#endif /* _KERNEL */

/* XXX The below breaks unified pmap on ppc32 */

#if !defined(CACHELINESIZE) && !defined(_MODULE) \
    && (defined(_KERNEL) || defined(_STANDALONE))
#if defined(PPC_IBM403)
#define	CACHELINESIZE		16
#define MAXCACHELINESIZE	16
#elif defined (PPC_OEA64_BRIDGE)
#define	CACHELINESIZE		128
#define MAXCACHELINESIZE	128
#else
#define	CACHELINESIZE		32
#define MAXCACHELINESIZE	32
#endif /* PPC_OEA64_BRIDGE */
#endif

void	__syncicache(void *, size_t);

/*
 * CTL_MACHDEP definitions.
 */
#define	CPU_CACHELINE		1
#define	CPU_TIMEBASE		2
#define	CPU_CPUTEMP		3
#define	CPU_PRINTFATALTRAPS	4
#define	CPU_CACHEINFO		5
#define	CPU_ALTIVEC		6
#define	CPU_MODEL		7
#define	CPU_POWERSAVE		8	/* int: use CPU powersave mode */
#define	CPU_BOOTED_DEVICE	9	/* string: device we booted from */
#define	CPU_BOOTED_KERNEL	10	/* string: kernel we booted */
#define	CPU_EXECPROT		11	/* bool: PROT_EXEC works */
#define	CPU_FPU			12
#define	CPU_NO_UNALIGNED	13	/* No HW support for unaligned access */

#endif	/* _POWERPC_CPU_H_ */