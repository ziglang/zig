/*	$NetBSD: cpu.h,v 1.133.4.1 2023/08/09 17:42:01 martin Exp $	*/

/*
 * Copyright (c) 1990 The Regents of the University of California.
 * All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * William Jolitz.
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
 *	@(#)cpu.h	5.4 (Berkeley) 5/9/91
 */

#ifndef _X86_CPU_H_
#define _X86_CPU_H_

#if defined(_KERNEL) || defined(_STANDALONE)
#include <sys/types.h>
#else
#include <stdint.h>
#include <stdbool.h>
#endif /* _KERNEL || _STANDALONE */

#if defined(_KERNEL) || defined(_KMEMUSER)
#if defined(_KERNEL_OPT)
#include "opt_xen.h"
#include "opt_svs.h"
#endif

/*
 * Definitions unique to x86 cpu support.
 */
#include <machine/frame.h>
#include <machine/pte.h>
#include <machine/segments.h>
#include <machine/tss.h>
#include <machine/intrdefs.h>

#include <x86/cacheinfo.h>

#include <sys/cpu_data.h>
#include <sys/evcnt.h>
#include <sys/device_if.h> /* for device_t */

#ifdef SVS
#include <sys/mutex.h>
#endif

#ifdef XEN
#include <xen/include/public/xen.h>
#include <xen/include/public/event_channel.h>
#include <sys/mutex.h>
#endif /* XEN */

struct intrsource;
struct pmap;
struct kcpuset;

#ifdef __x86_64__
#define	i386tss	x86_64_tss
#endif

#define	NIOPORTS	1024		/* # of ports we allow to be mapped */
#define	IOMAPSIZE	(NIOPORTS / 8)	/* I/O bitmap size in bytes */

struct cpu_tss {
#ifdef i386
	struct i386tss dblflt_tss;
	struct i386tss ddbipi_tss;
#endif
	struct i386tss tss;
	uint8_t iomap[IOMAPSIZE];
} __packed;

/*
 * Arguments to hardclock, softclock and statclock
 * encapsulate the previous machine state in an opaque
 * clockframe; for now, use generic intrframe.
 */
struct clockframe {
	struct intrframe cf_if;
};

struct idt_vec {
	void *iv_idt;
	void *iv_idt_pentium;
	char iv_allocmap[NIDT];
};

/*
 * a bunch of this belongs in cpuvar.h; move it later..
 */

struct cpu_info {
	struct cpu_data ci_data;	/* MI per-cpu data */
	device_t ci_dev;		/* pointer to our device */
	struct cpu_info *ci_self;	/* self-pointer */

	/*
	 * Private members.
	 */
	struct pmap *ci_pmap;		/* current pmap */
	int ci_want_pmapload;		/* pmap_load() is needed */
	volatile int ci_tlbstate;	/* one of TLBSTATE_ states. see below */
#define	TLBSTATE_VALID	0	/* all user tlbs are valid */
#define	TLBSTATE_LAZY	1	/* tlbs are valid but won't be kept uptodate */
#define	TLBSTATE_STALE	2	/* we might have stale user tlbs */
	int ci_curldt;		/* current LDT descriptor */
	int ci_nintrhand;	/* number of H/W interrupt handlers */
	uint64_t ci_scratch;
	uintptr_t ci_pmap_data[128 / sizeof(uintptr_t)];
	struct kcpuset *ci_tlb_cpuset;
	struct idt_vec ci_idtvec;

	int ci_kfpu_spl;

	struct intrsource *ci_isources[MAX_INTR_SOURCES];
	
	volatile int	ci_mtx_count;	/* Negative count of spin mutexes */
	volatile int	ci_mtx_oldspl;	/* Old SPL at this ci_idepth */

	/* The following must be aligned for cmpxchg8b. */
	union {
		uint64_t	ci_istate;
		struct {
			uint64_t	ci_ipending:56;
			uint64_t	ci_ilevel:8;
		};
	} __aligned(8);
	uint64_t	ci_imasked;

	int		ci_idepth;
	void *		ci_intrstack;
	uint64_t	ci_imask[NIPL];
	uint64_t	ci_iunmask[NIPL];

	uint32_t	ci_signature;	/* X86 cpuid type (cpuid.1.%eax) */
	uint32_t	ci_vendor[4];	/* vendor string */
	uint32_t	ci_max_cpuid;	/* cpuid.0:%eax */
	uint32_t	ci_max_ext_cpuid; /* cpuid.80000000:%eax */
	volatile uint32_t	ci_lapic_counter;

	uint32_t	ci_feat_val[8]; /* X86 CPUID feature bits */
			/* [0] basic features cpuid.1:%edx
			 * [1] basic features cpuid.1:%ecx (CPUID2_xxx bits)
			 * [2] extended features cpuid:80000001:%edx
			 * [3] extended features cpuid:80000001:%ecx
			 * [4] VIA padlock features
			 * [5] structured extended features cpuid.7:%ebx
			 * [6] structured extended features cpuid.7:%ecx
			 * [7] structured extended features cpuid.7:%edx
			 */
	
	const struct cpu_functions *ci_func;  /* start/stop functions */
	struct trapframe *ci_ddb_regs;

	u_int ci_cflush_lsize;	/* CLFLUSH insn line size */
	struct x86_cache_info ci_cinfo[CAI_COUNT];

	device_t	ci_frequency;	/* Frequency scaling technology */
	device_t	ci_padlock;	/* VIA PadLock private storage */
	device_t	ci_temperature;	/* Intel coretemp(4) or equivalent */
	device_t	ci_vm;		/* Virtual machine guest driver */

	/*
	 * Segmentation-related data.
	 */
	union descriptor *ci_gdt;
	struct cpu_tss	*ci_tss;	/* Per-cpu TSSes; shared among LWPs */
	int ci_tss_sel;			/* TSS selector of this cpu */

	/*
	 * The following two are actually region_descriptors,
	 * but that would pollute the namespace.
	 */
	uintptr_t	ci_suspend_gdt;
	uint16_t	ci_suspend_gdt_padding;
	uintptr_t	ci_suspend_idt;
	uint16_t	ci_suspend_idt_padding;

	uint16_t	ci_suspend_tr;
	uint16_t	ci_suspend_ldt;
	uintptr_t	ci_suspend_fs;
	uintptr_t	ci_suspend_gs;
	uintptr_t	ci_suspend_kgs;
	uintptr_t	ci_suspend_efer;
	uintptr_t	ci_suspend_reg[12];
	uintptr_t	ci_suspend_cr0;
	uintptr_t	ci_suspend_cr2;
	uintptr_t	ci_suspend_cr3;
	uintptr_t	ci_suspend_cr4;
	uintptr_t	ci_suspend_cr8;

	/*
	 * The following must be in their own cache line, as they are
	 * stored to regularly by remote CPUs; when they were mixed with
	 * other fields we observed frequent cache misses.
	 */
	int		ci_want_resched __aligned(64);
	uint32_t	ci_ipis; /* interprocessor interrupts pending */

	/*
	 * These are largely static, and will be frequently fetched by other
	 * CPUs.  For that reason they get their own cache line, too.
	 */
	uint32_t 	ci_flags __aligned(64);/* general flags */
	uint32_t 	ci_acpiid;	/* our ACPI/MADT ID */
	uint32_t 	ci_initapicid;	/* our initial APIC ID */
	uint32_t 	ci_vcpuid;	/* our CPU id for hypervisor */
	cpuid_t		ci_cpuid;	/* our CPU ID */
	struct cpu_info	*ci_next;	/* next cpu */

	/*
	 * This is stored frequently, and is fetched by remote CPUs.
	 */
	struct lwp	*ci_curlwp __aligned(64);/* general flags */
	struct lwp	*ci_onproc;	/* current user LWP / kthread */

	/* Here ends the cachline-aligned sections. */
	int		ci_padout __aligned(64);

#ifndef __HAVE_DIRECT_MAP
#define VPAGE_SRC 0
#define VPAGE_DST 1
#define VPAGE_ZER 2
#define VPAGE_PTP 3
#define VPAGE_MAX 4
	vaddr_t		vpage[VPAGE_MAX];
	pt_entry_t	*vpage_pte[VPAGE_MAX];
#endif

#ifdef PAE
	uint32_t	ci_pae_l3_pdirpa; /* PA of L3 PD */
	pd_entry_t *	ci_pae_l3_pdir; /* VA pointer to L3 PD */
#endif

#ifdef SVS
	pd_entry_t *	ci_svs_updir;
	paddr_t		ci_svs_updirpa;
	int		ci_svs_ldt_sel;
	kmutex_t	ci_svs_mtx;
	pd_entry_t *	ci_svs_rsp0_pte;
	vaddr_t		ci_svs_rsp0;
	vaddr_t		ci_svs_ursp0;
	vaddr_t		ci_svs_krsp0;
	vaddr_t		ci_svs_utls;
#endif

#ifndef XENPV
	struct evcnt ci_ipi_events[X86_NIPI];
#else
	struct evcnt ci_ipi_events[XEN_NIPIS];
#endif
#ifdef XEN
	volatile struct vcpu_info *ci_vcpu; /* for XEN */
	u_long ci_evtmask[NR_EVENT_CHANNELS]; /* events allowed on this CPU */
	evtchn_port_t ci_ipi_evtchn;
#if defined(XENPV)
#if defined(PAE) || defined(__x86_64__)
	/* Currently active user PGD (can't use rcr3() with Xen) */
	pd_entry_t *	ci_kpm_pdir;	/* per-cpu PMD (va) */
	paddr_t		ci_kpm_pdirpa;  /* per-cpu PMD (pa) */
	kmutex_t	ci_kpm_mtx;
#endif /* defined(PAE) || defined(__x86_64__) */

#if defined(__x86_64__)
	/* per-cpu version of normal_pdes */
	pd_entry_t *	ci_normal_pdes[3]; /* Ok to hardcode. only for x86_64 && XENPV */
	paddr_t		ci_xen_current_user_pgd;
#endif	/* defined(__x86_64__) */

	size_t		ci_xpq_idx;
#endif /* XENPV */

	/* Xen raw system time at which we last ran hardclock.  */
	uint64_t	ci_xen_hardclock_systime_ns;

	/*
	 * Last TSC-adjusted local Xen system time we observed.  Used
	 * to detect whether the Xen clock has gone backwards.
	 */
	uint64_t	ci_xen_last_systime_ns;

	/*
	 * Distance in nanoseconds from the local view of system time
	 * to the global view of system time, if the local time is
	 * behind the global time.
	 */
	uint64_t	ci_xen_systime_ns_skew;

	/*
	 * Clockframe for timer interrupt handler.
	 * Saved at entry via event callback.
	 */
	vaddr_t ci_xen_clockf_pc; /* RIP at last event interrupt */
	bool ci_xen_clockf_usermode; /* Was the guest in usermode ? */

	/* Event counters for various pathologies that might happen.  */
	struct evcnt	ci_xen_cpu_tsc_backwards_evcnt;
	struct evcnt	ci_xen_tsc_delta_negative_evcnt;
	struct evcnt	ci_xen_raw_systime_wraparound_evcnt;
	struct evcnt	ci_xen_raw_systime_backwards_evcnt;
	struct evcnt	ci_xen_systime_backwards_hardclock_evcnt;
	struct evcnt	ci_xen_missed_hardclock_evcnt;
#endif	/* XEN */

#if defined(GPROF) && defined(MULTIPROCESSOR)
	struct gmonparam *ci_gmon;	/* MI per-cpu GPROF */
#endif
};

#if defined(XEN) && !defined(XENPV)
	__CTASSERT(XEN_NIPIS <= X86_NIPI);
#endif

/*
 * Macros to handle (some) trapframe registers for common x86 code.
 */
#ifdef __x86_64__
#define	X86_TF_RAX(tf)		tf->tf_rax
#define	X86_TF_RDX(tf)		tf->tf_rdx
#define	X86_TF_RSP(tf)		tf->tf_rsp
#define	X86_TF_RIP(tf)		tf->tf_rip
#define	X86_TF_RFLAGS(tf)	tf->tf_rflags
#else
#define	X86_TF_RAX(tf)		tf->tf_eax
#define	X86_TF_RDX(tf)		tf->tf_edx
#define	X86_TF_RSP(tf)		tf->tf_esp
#define	X86_TF_RIP(tf)		tf->tf_eip
#define	X86_TF_RFLAGS(tf)	tf->tf_eflags
#endif

/*
 * Processor flag notes: The "primary" CPU has certain MI-defined
 * roles (mostly relating to hardclock handling); we distinguish
 * between the processor which booted us, and the processor currently
 * holding the "primary" role just to give us the flexibility later to
 * change primaries should we be sufficiently twisted.
 */

#define	CPUF_BSP	0x0001		/* CPU is the original BSP */
#define	CPUF_AP		0x0002		/* CPU is an AP */
#define	CPUF_SP		0x0004		/* CPU is only processor */
#define	CPUF_PRIMARY	0x0008		/* CPU is active primary processor */

#define	CPUF_SYNCTSC	0x0800		/* Synchronize TSC */
#define	CPUF_PRESENT	0x1000		/* CPU is present */
#define	CPUF_RUNNING	0x2000		/* CPU is running */
#define	CPUF_PAUSE	0x4000		/* CPU is paused in DDB */
#define	CPUF_GO		0x8000		/* CPU should start running */

#endif /* _KERNEL || __KMEMUSER */

#ifdef _KERNEL
/*
 * We statically allocate the CPU info for the primary CPU (or,
 * the only CPU on uniprocessors), and the primary CPU is the
 * first CPU on the CPU info list.
 */
extern struct cpu_info cpu_info_primary;
extern struct cpu_info *cpu_info_list;

#define	CPU_INFO_ITERATOR		int __unused
#define	CPU_INFO_FOREACH(cii, ci)	ci = cpu_info_list; \
					ci != NULL; ci = ci->ci_next

#define CPU_STARTUP(_ci, _target)	((_ci)->ci_func->start(_ci, _target))
#define CPU_STOP(_ci)	        	((_ci)->ci_func->stop(_ci))
#define CPU_START_CLEANUP(_ci)		((_ci)->ci_func->cleanup(_ci))

#if !defined(__GNUC__) || defined(_MODULE)
/* For non-GCC and modules */
struct cpu_info	*x86_curcpu(void);
# ifdef __GNUC__
lwp_t	*x86_curlwp(void) __attribute__ ((const));
# else
lwp_t   *x86_curlwp(void);
# endif
#endif

#define cpu_number() 		(cpu_index(curcpu()))

#define CPU_IS_PRIMARY(ci)	((ci)->ci_flags & CPUF_PRIMARY)

#define aston(l)		((l)->l_md.md_astpending = 1)

void cpu_boot_secondary_processors(void);
void cpu_init_idle_lwps(void);
void cpu_init_msrs(struct cpu_info *, bool);
void cpu_load_pmap(struct pmap *, struct pmap *);
void cpu_broadcast_halt(void);
void cpu_kick(struct cpu_info *);

void cpu_pcpuarea_init(struct cpu_info *);
void cpu_svs_init(struct cpu_info *);
void cpu_speculation_init(struct cpu_info *);

#define	curcpu()		x86_curcpu()
#define	curlwp			x86_curlwp()
#define	curpcb			((struct pcb *)lwp_getpcb(curlwp))

/*
 * Give a profiling tick to the current process when the user profiling
 * buffer pages are invalid.  On the i386, request an ast to send us
 * through trap(), marking the proc as needing a profiling tick.
 */
extern void	cpu_need_proftick(struct lwp *l);

/*
 * Notify the LWP l that it has a signal pending, process as soon as
 * possible.
 */
extern void	cpu_signotify(struct lwp *);

/*
 * We need a machine-independent name for this.
 */
extern void (*delay_func)(unsigned int);
struct timeval;

#ifndef __HIDE_DELAY
#define	DELAY(x)		(*delay_func)(x)
#define delay(x)		(*delay_func)(x)
#endif

extern int biosbasemem;
extern int biosextmem;
extern int cputype;
extern int cpuid_level;
extern int cpu_class;
extern char cpu_brand_string[];
extern int use_pae;

#ifdef __i386__
#define	i386_fpu_present	1
int npx586bug1(int, int);
extern int i386_fpu_fdivbug;
extern int i386_use_fxsave;
extern int i386_has_sse;
extern int i386_has_sse2;
#else
#define	i386_fpu_present	1
#define	i386_fpu_fdivbug	0
#define	i386_use_fxsave		1
#define	i386_has_sse		1
#define	i386_has_sse2		1
#endif

extern int x86_fpu_save;
#define	FPU_SAVE_FSAVE		0
#define	FPU_SAVE_FXSAVE		1
#define	FPU_SAVE_XSAVE		2
#define	FPU_SAVE_XSAVEOPT	3
extern unsigned int x86_fpu_save_size;
extern uint64_t x86_xsave_features;
extern size_t x86_xsave_offsets[];
extern size_t x86_xsave_sizes[];
extern uint32_t x86_fpu_mxcsr_mask;

extern void (*x86_cpu_idle)(void);
#define	cpu_idle() (*x86_cpu_idle)()

/* machdep.c */
#ifdef i386
void	cpu_set_tss_gates(struct cpu_info *);
#endif
void	cpu_reset(void);

/* longrun.c */
u_int 	tmx86_get_longrun_mode(void);
void 	tmx86_get_longrun_status(u_int *, u_int *, u_int *);
void 	tmx86_init_longrun(void);

/* identcpu.c */
void 	cpu_probe(struct cpu_info *);
void	cpu_identify(struct cpu_info *);
void	identify_hypervisor(void);

/* identcpu_subr.c */
uint64_t cpu_tsc_freq_cpuid(struct cpu_info *);
void	cpu_dcp_cacheinfo(struct cpu_info *, uint32_t);

typedef enum vm_guest {
	VM_GUEST_NO = 0,
	VM_GUEST_VM,
	VM_GUEST_XENPV,
	VM_GUEST_XENPVH,
	VM_GUEST_XENHVM,
	VM_GUEST_XENPVHVM,
	VM_GUEST_HV,
	VM_GUEST_VMWARE,
	VM_GUEST_KVM,
	VM_GUEST_VIRTUALBOX,
	VM_LAST
} vm_guest_t;
extern vm_guest_t vm_guest;

static __inline bool __unused
vm_guest_is_xenpv(void)
{
	switch(vm_guest) {
	case VM_GUEST_XENPV:
	case VM_GUEST_XENPVH:
	case VM_GUEST_XENPVHVM:
		return true;
	default:
		return false;
	}
}

static __inline bool __unused
vm_guest_is_xenpvh_or_pvhvm(void)
{
	switch(vm_guest) {
	case VM_GUEST_XENPVH:
	case VM_GUEST_XENPVHVM:
		return true;
	default:
		return false;
	}
}

/* cpu_topology.c */
void	x86_cpu_topology(struct cpu_info *);

/* locore.s */
struct region_descriptor;
void	lgdt(struct region_descriptor *);
#ifdef XENPV
void	lgdt_finish(void);
#endif

struct pcb;
void	savectx(struct pcb *);
void	lwp_trampoline(void);
#ifdef XEN
void	xen_startrtclock(void);
void	xen_delay(unsigned int);
void	xen_initclocks(void);
void	xen_cpu_initclocks(void);
void	xen_suspendclocks(struct cpu_info *);
void	xen_resumeclocks(struct cpu_info *);
#endif /* XEN */
/* clock.c */
void	initrtclock(u_long);
void	startrtclock(void);
void	i8254_delay(unsigned int);
void	i8254_microtime(struct timeval *);
void	i8254_initclocks(void);
unsigned int gettick(void);
extern void (*x86_delay)(unsigned int);

/* cpu.c */
void	cpu_probe_features(struct cpu_info *);
int	x86_cpu_is_lcall(const void *);

/* vm_machdep.c */
void	cpu_proc_fork(struct proc *, struct proc *);
paddr_t	kvtop(void *);

/* isa_machdep.c */
void	isa_defaultirq(void);
int	isa_nmi(void);

/* consinit.c */
void kgdb_port_init(void);

/* bus_machdep.c */
void x86_bus_space_init(void);
void x86_bus_space_mallocok(void);

#endif /* _KERNEL */

#if defined(_KERNEL) || defined(_KMEMUSER)
#include <machine/psl.h>	/* Must be after struct cpu_info declaration */
#endif /* _KERNEL || __KMEMUSER */

/*
 * CTL_MACHDEP definitions.
 */
#define	CPU_CONSDEV		1	/* dev_t: console terminal device */
#define	CPU_BIOSBASEMEM		2	/* int: bios-reported base mem (K) */
#define	CPU_BIOSEXTMEM		3	/* int: bios-reported ext. mem (K) */
/* 	CPU_NKPDE		4	obsolete: int: number of kernel PDEs */
#define	CPU_BOOTED_KERNEL	5	/* string: booted kernel name */
#define CPU_DISKINFO		6	/* struct disklist *:
					 * disk geometry information */
#define CPU_FPU_PRESENT		7	/* int: FPU is present */
#define	CPU_OSFXSR		8	/* int: OS uses FXSAVE/FXRSTOR */
#define	CPU_SSE			9	/* int: OS/CPU supports SSE */
#define	CPU_SSE2		10	/* int: OS/CPU supports SSE2 */
#define	CPU_TMLR_MODE		11	/* int: longrun mode
					 * 0: minimum frequency
					 * 1: economy
					 * 2: performance
					 * 3: maximum frequency
					 */
#define	CPU_TMLR_FREQUENCY	12	/* int: current frequency */
#define	CPU_TMLR_VOLTAGE	13	/* int: current voltage */
#define	CPU_TMLR_PERCENTAGE	14	/* int: current clock percentage */
#define	CPU_FPU_SAVE		15	/* int: FPU Instructions layout
					 * to use this, CPU_OSFXSR must be true
					 * 0: FSAVE
					 * 1: FXSAVE
					 * 2: XSAVE
					 * 3: XSAVEOPT
					 */
#define	CPU_FPU_SAVE_SIZE	16	/* int: FPU Instruction layout size */
#define	CPU_XSAVE_FEATURES	17	/* quad: XSAVE features */

/*
 * Structure for CPU_DISKINFO sysctl call.
 * XXX this should be somewhere else.
 */
#define MAX_BIOSDISKS	16

struct disklist {
	int dl_nbiosdisks;			   /* number of bios disks */
	int dl_unused;
	struct biosdisk_info {
		int bi_dev;			   /* BIOS device # (0x80 ..) */
		int bi_cyl;			   /* cylinders on disk */
		int bi_head;			   /* heads per track */
		int bi_sec;			   /* sectors per track */
		uint64_t bi_lbasecs;		   /* total sec. (iff ext13) */
#define BIFLAG_INVALID		0x01
#define BIFLAG_EXTINT13		0x02
		int bi_flags;
		int bi_unused;
	} dl_biosdisks[MAX_BIOSDISKS];

	int dl_nnativedisks;			   /* number of native disks */
	struct nativedisk_info {
		char ni_devname[16];		   /* native device name */
		int ni_nmatches; 		   /* # of matches w/ BIOS */
		int ni_biosmatches[MAX_BIOSDISKS]; /* indices in dl_biosdisks */
	} dl_nativedisks[1];			   /* actually longer */
};
#endif /* !_X86_CPU_H_ */