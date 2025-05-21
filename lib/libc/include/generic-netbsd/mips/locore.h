/* $NetBSD: locore.h,v 1.119 2021/05/27 15:00:02 simonb Exp $ */

/*
 * This file should not be included by MI code!!!
 */

/*
 * Copyright 1996 The Board of Trustees of The Leland Stanford
 * Junior University. All Rights Reserved.
 *
 * Permission to use, copy, modify, and distribute this
 * software and its documentation for any purpose and without
 * fee is hereby granted, provided that the above copyright
 * notice appear in all copies.  Stanford University
 * makes no representations about the suitability of this
 * software for any purpose.  It is provided "as is" without
 * express or implied warranty.
 */

/*
 * Jump table for MIPS CPU locore functions that are implemented
 * differently on different generations, or instruction-level
 * architecture (ISA) level, the Mips family.
 *
 * We currently provide support for MIPS I and MIPS III.
 */

#ifndef _MIPS_LOCORE_H
#define	_MIPS_LOCORE_H

#if !defined(_MODULE) && defined(_KERNEL_OPT)
#include "opt_cputype.h"
#endif

#ifndef __ASSEMBLER__

#include <sys/cpu.h>

#include <mips/mutex.h>
#include <mips/cpuregs.h>
#include <mips/reg.h>

#ifndef __BSD_PTENTRY_T__
#define	__BSD_PTENTRY_T__
typedef uint32_t pt_entry_t;
#define	PRIxPTE		PRIx32
#endif

#include <uvm/pmap/tlb.h>
#endif /* !__ASSEMBLER__ */

#ifdef _KERNEL

#if defined(_MODULE) || defined(_STANDALONE)
/* Assume all CPU architectures are valid for modules and standlone progs */
#if !defined(__mips_n32) && !defined(__mips_n64)
#define	MIPS1		1
#endif
#define	MIPS3		1
#define	MIPS4		1
#if !defined(__mips_n32) && !defined(__mips_n64)
#define	MIPS32		1
#define	MIPS32R2	1
#endif
#define	MIPS64		1
#define	MIPS64R2	1
#endif /* _MODULE || _STANDALONE */

#if (MIPS1 + MIPS3 + MIPS4 + MIPS32 + MIPS32R2 + MIPS64 + MIPS64R2) == 0
#error at least one of MIPS1, MIPS3, MIPS4, MIPS32, MIPS32R2, MIPS64, or MIPS64R2 must be specified
#endif

/* Shortcut for MIPS3 or above defined */
#if defined(MIPS3) || defined(MIPS4) \
    || defined(MIPS32) || defined(MIPS32R2) \
    || defined(MIPS64) || defined(MIPS64R2)

#define	MIPS3_PLUS	1
#if !defined(MIPS32) && !defined(MIPS32R2)
#define	MIPS3_64BIT	1
#endif
#if !defined(MIPS3) && !defined(MIPS4)
#define	MIPSNN		1
#endif
#if defined(MIPS32R2) || defined(MIPS64R2)
#define	MIPSNNR2	1
#endif
#else
#undef MIPS3_PLUS
#endif

#if defined(MIPS1) && (ENABLE_MIPS_8KB_PAGE + ENABLE_MIPS_16KB_PAGE) > 0
#error MIPS1 only supports a 4kB page size.
#endif

/* XXX some .S files look for MIPS3_PLUS */
#ifndef __ASSEMBLER__
#ifdef _KERNEL

/* XXX simonb
 * Should the following be in a cpu_info type structure?
 * And how many of these are per-cpu vs. per-system?  (Ie,
 * we can assume that all cpus have the same mmu-type, but
 * maybe not that all cpus run at the same clock speed.
 * Some SGI's apparently support R12k and R14k in the same
 * box.)
 */
struct mips_options {
	const struct pridtab *mips_cpu;

	u_int mips_cpu_arch;
	u_int mips_cpu_mhz; /* CPU speed in MHz, estimated by mc_cpuspeed(). */
	u_int mips_cpu_flags;
	u_int mips_num_tlb_entries;
	mips_prid_t mips_cpu_id;
	mips_prid_t mips_fpu_id;
	bool mips_has_r4k_mmu;
	bool mips_has_llsc;
	u_int mips3_pg_shift;
	u_int mips3_pg_cached;
	u_int mips3_cca_devmem;
#ifdef MIPS3_PLUS
#ifndef __mips_o32
	uint64_t mips3_xkphys_cached;
#endif
	uint64_t mips3_tlb_vpn_mask;
	uint64_t mips3_tlb_pfn_mask;
	uint32_t mips3_tlb_pg_mask;
#endif
};

#endif /* !__ASSEMBLER__ */

/*
 * Macros to find the CPU architecture we're on at run-time,
 * or if possible, at compile-time.
 */

#define	CPU_ARCH_MIPSx		0		/* XXX unknown */
#define	CPU_ARCH_MIPS1		(1 << 0)
#define	CPU_ARCH_MIPS2		(1 << 1)
#define	CPU_ARCH_MIPS3		(1 << 2)
#define	CPU_ARCH_MIPS4		(1 << 3)
#define	CPU_ARCH_MIPS5		(1 << 4)
#define	CPU_ARCH_MIPS32		(1 << 5)
#define	CPU_ARCH_MIPS64		(1 << 6)
#define	CPU_ARCH_MIPS32R2	(1 << 7)
#define	CPU_ARCH_MIPS64R2	(1 << 8)

#define	CPU_MIPS_R4K_MMU		0x00001
#define	CPU_MIPS_NO_LLSC		0x00002
#define	CPU_MIPS_CAUSE_IV		0x00004
#define	CPU_MIPS_HAVE_SPECIAL_CCA	0x00008	/* Defaults to '3' if not set. */
#define	CPU_MIPS_CACHED_CCA_MASK	0x00070
#define	CPU_MIPS_CACHED_CCA_SHIFT	 4
#define	CPU_MIPS_DOUBLE_COUNT		0x00080	/* 1 cp0 count == 2 clock cycles */
#define	CPU_MIPS_USE_WAIT		0x00100	/* Use "wait"-based cpu_idle() */
#define	CPU_MIPS_NO_WAIT		0x00200	/* Inverse of previous, for mips32/64 */
#define	CPU_MIPS_D_CACHE_COHERENT	0x00400	/* D-cache is fully coherent */
#define	CPU_MIPS_I_D_CACHE_COHERENT	0x00800	/* I-cache funcs don't need to flush the D-cache */
#define	CPU_MIPS_NO_LLADDR		0x01000
#define	CPU_MIPS_HAVE_MxCR		0x02000	/* have mfcr, mtcr insns */
#define	CPU_MIPS_LOONGSON2		0x04000
#define	MIPS_NOT_SUPP			0x08000
#define	CPU_MIPS_HAVE_DSP		0x10000
#define	CPU_MIPS_HAVE_USERLOCAL		0x20000

#endif	/* !_LOCORE */

#if ((MIPS1 + MIPS3 + MIPS4 + MIPS32 + MIPS32R2 + MIPS64 + MIPS64R2) == 1) || defined(_LOCORE)

#if defined(MIPS1)

# define CPUISMIPS3		0
# define CPUIS64BITS		0
# define CPUISMIPS32		0
# define CPUISMIPS32R2		0
# define CPUISMIPS64		0
# define CPUISMIPS64R2		0
# define CPUISMIPSNN		0
# define CPUISMIPSNNR2		0
# define MIPS_HAS_R4K_MMU	0
# define MIPS_HAS_CLOCK		0
# define MIPS_HAS_LLSC		0
# define MIPS_HAS_LLADDR	0
# define MIPS_HAS_LMMI		0
# define MIPS_HAS_DSP		0
# define MIPS_HAS_USERLOCAL	0

#elif defined(MIPS3) || defined(MIPS4)

# define CPUISMIPS3		1
# define CPUIS64BITS		1
# define CPUISMIPS32		0
# define CPUISMIPS32R2		0
# define CPUISMIPS64		0
# define CPUISMIPS64R2		0
# define CPUISMIPSNN		0
# define CPUISMIPSNNR2		0
# define MIPS_HAS_R4K_MMU	1
# define MIPS_HAS_CLOCK		1
# if defined(_LOCORE)
#  if !defined(MIPS3_4100)
#   define MIPS_HAS_LLSC	1
#  else
#   define MIPS_HAS_LLSC	0
#  endif
# else	/* _LOCORE */
#  define MIPS_HAS_LLSC		(mips_options.mips_has_llsc)
# endif	/* _LOCORE */
# define MIPS_HAS_LLADDR	((mips_options.mips_cpu_flags & CPU_MIPS_NO_LLADDR) == 0)
# if defined(MIPS3_LOONGSON2)
#  define MIPS_HAS_LMMI		((mips_options.mips_cpu_flags & CPU_MIPS_LOONGSON2) != 0)
# else
#  define MIPS_HAS_LMMI		0
# endif
# define MIPS_HAS_DSP		0
# define MIPS_HAS_USERLOCAL	0

#elif defined(MIPS32)

# define CPUISMIPS3		1
# define CPUIS64BITS		0
# define CPUISMIPS32		1
# define CPUISMIPS32R2		0
# define CPUISMIPS64		0
# define CPUISMIPS64R2		0
# define CPUISMIPSNN		1
# define CPUISMIPSNNR2		0
# define MIPS_HAS_R4K_MMU	1
# define MIPS_HAS_CLOCK		1
# define MIPS_HAS_LLSC		1
# define MIPS_HAS_LLADDR	((mips_options.mips_cpu_flags & CPU_MIPS_NO_LLADDR) == 0)
# define MIPS_HAS_LMMI		0
# define MIPS_HAS_DSP		0
# define MIPS_HAS_USERLOCAL	0

#elif defined(MIPS32R2)

# define CPUISMIPS3		1
# define CPUIS64BITS		0
# define CPUISMIPS32		0
# define CPUISMIPS32R2		1
# define CPUISMIPS64		0
# define CPUISMIPS64R2		0
# define CPUISMIPSNN		1
# define CPUISMIPSNNR2		1
# define MIPS_HAS_R4K_MMU	1
# define MIPS_HAS_CLOCK		1
# define MIPS_HAS_LLSC		1
# define MIPS_HAS_LLADDR	((mips_options.mips_cpu_flags & CPU_MIPS_NO_LLADDR) == 0)
# define MIPS_HAS_LMMI		0
# define MIPS_HAS_DSP		(mips_options.mips_cpu_flags & CPU_MIPS_HAVE_DSP)
# define MIPS_HAS_USERLOCAL	(mips_options.mips_cpu_flags & CPU_MIPS_HAVE_USERLOCAL)

#elif defined(MIPS64)

# define CPUISMIPS3		1
# define CPUIS64BITS		1
# define CPUISMIPS32		0
# define CPUISMIPS32R2		0
# define CPUISMIPS64		1
# define CPUISMIPS64R2		0
# define CPUISMIPSNN		1
# define CPUISMIPSNNR2		0
# define MIPS_HAS_R4K_MMU	1
# define MIPS_HAS_CLOCK		1
# define MIPS_HAS_LLSC		1
# define MIPS_HAS_LLADDR	((mips_options.mips_cpu_flags & CPU_MIPS_NO_LLADDR) == 0)
# define MIPS_HAS_LMMI		0
# define MIPS_HAS_DSP		0
# define MIPS_HAS_USERLOCAL	0

#elif defined(MIPS64R2)

# define CPUISMIPS3		1
# define CPUIS64BITS		1
# define CPUISMIPS32		0
# define CPUISMIPS32R2		0
# define CPUISMIPS64		0
# define CPUISMIPS64R2		1
# define CPUISMIPSNN		1
# define CPUISMIPSNNR2		1
# define MIPS_HAS_R4K_MMU	1
# define MIPS_HAS_CLOCK		1
# define MIPS_HAS_LLSC		1
# define MIPS_HAS_LLADDR	((mips_options.mips_cpu_flags & CPU_MIPS_NO_LLADDR) == 0)
# define MIPS_HAS_LMMI		0
# define MIPS_HAS_DSP		(mips_options.mips_cpu_flags & CPU_MIPS_HAVE_DSP)
# define MIPS_HAS_USERLOCAL	(mips_options.mips_cpu_flags & CPU_MIPS_HAVE_USERLOCAL)

#endif

#else /* run-time test */

#ifdef MIPS1
#define	MIPS_HAS_R4K_MMU	(mips_options.mips_has_r4k_mmu)
#define	MIPS_HAS_LLSC		(mips_options.mips_has_llsc)
#else
#define	MIPS_HAS_R4K_MMU	1
#if !defined(MIPS3_4100)
#define	MIPS_HAS_LLSC		1
#else
#define	MIPS_HAS_LLSC		(mips_options.mips_has_llsc)
#endif
#endif
#define	MIPS_HAS_LLADDR		((mips_options.mips_cpu_flags & CPU_MIPS_NO_LLADDR) == 0)
#define	MIPS_HAS_DSP		(mips_options.mips_cpu_flags & CPU_MIPS_HAVE_DSP)
#define MIPS_HAS_USERLOCAL	(mips_options.mips_cpu_flags & CPU_MIPS_HAVE_USERLOCAL)

/* This test is ... rather bogus */
#define	CPUISMIPS3	((mips_options.mips_cpu_arch & \
	(CPU_ARCH_MIPS3 | CPU_ARCH_MIPS4 | CPU_ARCH_MIPS32 | CPU_ARCH_MIPS64)) != 0)

/* And these aren't much better while the previous test exists as is... */
#define	CPUISMIPS4	((mips_options.mips_cpu_arch & CPU_ARCH_MIPS4) != 0)
#define	CPUISMIPS5	((mips_options.mips_cpu_arch & CPU_ARCH_MIPS5) != 0)
#define	CPUISMIPS32	((mips_options.mips_cpu_arch & CPU_ARCH_MIPS32) != 0)
#define	CPUISMIPS32R2	((mips_options.mips_cpu_arch & CPU_ARCH_MIPS32R2) != 0)
#define	CPUISMIPS64	((mips_options.mips_cpu_arch & CPU_ARCH_MIPS64) != 0)
#define	CPUISMIPS64R2	((mips_options.mips_cpu_arch & CPU_ARCH_MIPS64R2) != 0)
#define	CPUISMIPSNN	((mips_options.mips_cpu_arch & \
	(CPU_ARCH_MIPS32 | CPU_ARCH_MIPS32R2 | CPU_ARCH_MIPS64 | CPU_ARCH_MIPS64R2)) != 0)
#define	CPUISMIPSNNR2	((mips_options.mips_cpu_arch & \
	(CPU_ARCH_MIPS32R2 | CPU_ARCH_MIPS64R2)) != 0)
#define	CPUIS64BITS	((mips_options.mips_cpu_arch & \
	(CPU_ARCH_MIPS3 | CPU_ARCH_MIPS4 | CPU_ARCH_MIPS64 | CPU_ARCH_MIPS64R2)) != 0)

#define	MIPS_HAS_CLOCK	(mips_options.mips_cpu_arch >= CPU_ARCH_MIPS3)

#endif /* run-time test */

#ifndef __ASSEMBLER__

struct tlbmask;
struct trapframe;

void	trap(uint32_t, uint32_t, vaddr_t, vaddr_t, struct trapframe *);
void	ast(void);

void	mips_fpu_trap(vaddr_t, struct trapframe *);
void	mips_fpu_intr(vaddr_t, struct trapframe *);

vaddr_t mips_emul_branch(struct trapframe *, vaddr_t, uint32_t, bool);
void	mips_emul_inst(uint32_t, uint32_t, vaddr_t, struct trapframe *);

void	mips_emul_fp(uint32_t, struct trapframe *, uint32_t);
void	mips_emul_branchdelayslot(uint32_t, struct trapframe *, uint32_t);

void	mips_emul_special(uint32_t, struct trapframe *, uint32_t);
void	mips_emul_special3(uint32_t, struct trapframe *, uint32_t);

void	mips_emul_lwc1(uint32_t, struct trapframe *, uint32_t);
void	mips_emul_swc1(uint32_t, struct trapframe *, uint32_t);
void	mips_emul_ldc1(uint32_t, struct trapframe *, uint32_t);
void	mips_emul_sdc1(uint32_t, struct trapframe *, uint32_t);

void	mips_emul_lb(uint32_t, struct trapframe *, uint32_t);
void	mips_emul_lbu(uint32_t, struct trapframe *, uint32_t);
void	mips_emul_lh(uint32_t, struct trapframe *, uint32_t);
void	mips_emul_lhu(uint32_t, struct trapframe *, uint32_t);
void	mips_emul_lw(uint32_t, struct trapframe *, uint32_t);
void	mips_emul_lwl(uint32_t, struct trapframe *, uint32_t);
void	mips_emul_lwr(uint32_t, struct trapframe *, uint32_t);
#if defined(__mips_n32) || defined(__mips_n64) || defined(__mips_o64)
void	mips_emul_lwu(uint32_t, struct trapframe *, uint32_t);
void	mips_emul_ld(uint32_t, struct trapframe *, uint32_t);
void	mips_emul_ldl(uint32_t, struct trapframe *, uint32_t);
void	mips_emul_ldr(uint32_t, struct trapframe *, uint32_t);
#endif
void	mips_emul_sb(uint32_t, struct trapframe *, uint32_t);
void	mips_emul_sh(uint32_t, struct trapframe *, uint32_t);
void	mips_emul_sw(uint32_t, struct trapframe *, uint32_t);
void	mips_emul_swl(uint32_t, struct trapframe *, uint32_t);
void	mips_emul_swr(uint32_t, struct trapframe *, uint32_t);
#if defined(__mips_n32) || defined(__mips_n64) || defined(__mips_o64)
void	mips_emul_sd(uint32_t, struct trapframe *, uint32_t);
void	mips_emul_sdl(uint32_t, struct trapframe *, uint32_t);
void	mips_emul_sdr(uint32_t, struct trapframe *, uint32_t);
#endif

uint32_t mips_cp0_cause_read(void);
void	mips_cp0_cause_write(uint32_t);
uint32_t mips_cp0_status_read(void);
void	mips_cp0_status_write(uint32_t);

void	softint_process(uint32_t);
void	softint_fast_dispatch(struct lwp *, int);

/*
 * Convert an address to an offset used in a MIPS jump instruction.  The offset
 * contains the low 28 bits (allowing a jump to anywhere within the same 256MB
 * segment of address space) of the address but since mips instructions are
 * always on a 4 byte boundary the low 2 bits are always zero so the 28 bits
 * get shifted right by 2 bits leaving us with a 26 bit result.  To make the
 * offset, we shift left to clear the upper four bits and then right by 6.
 */
#define	fixup_addr2offset(x)	((((uint32_t)(uintptr_t)(x)) << 4) >> 6)
typedef bool (*mips_fixup_callback_t)(int32_t, uint32_t [2], void *);
struct mips_jump_fixup_info {
	uint32_t jfi_stub;
	uint32_t jfi_real;
};

void	fixup_splcalls(void);				/* splstubs.c */
bool	mips_fixup_exceptions(mips_fixup_callback_t, void *);
bool	mips_fixup_zero_relative(int32_t, uint32_t [2], void *);
intptr_t
	mips_fixup_addr(const uint32_t *);
void	mips_fixup_stubs(uint32_t *, uint32_t *);

/*
 * Define these stubs...
 */
void	mips_cpu_switch_resume(struct lwp *);
void	wbflush(void);

#ifdef MIPS1
void	mips1_tlb_invalidate_all(void);

uint32_t tx3900_cp0_config_read(void);
#endif

#ifdef MIPS3_PLUS
uint32_t mips3_cp0_compare_read(void);
void	mips3_cp0_compare_write(uint32_t);

uint32_t mips3_cp0_config_read(void);
void	mips3_cp0_config_write(uint32_t);

#ifdef MIPSNN
uint32_t mipsNN_cp0_config1_read(void);
void	mipsNN_cp0_config1_write(uint32_t);
uint32_t mipsNN_cp0_config2_read(void);
uint32_t mipsNN_cp0_config3_read(void);
uint32_t mipsNN_cp0_config4_read(void);
uint32_t mipsNN_cp0_config5_read(void);
uint32_t mipsNN_cp0_config6_read(void);
uint32_t mipsNN_cp0_config7_read(void);

intptr_t mipsNN_cp0_watchlo_read(u_int);
void	mipsNN_cp0_watchlo_write(u_int, intptr_t);
uint32_t mipsNN_cp0_watchhi_read(u_int);
void	mipsNN_cp0_watchhi_write(u_int, uint32_t);

int32_t mipsNN_cp0_ebase_read(void);
void	mipsNN_cp0_ebase_write(int32_t);

uint32_t mipsNN_cp0_rdhwr_cpunum(void);

#ifdef MIPSNNR2
void	mipsNN_cp0_hwrena_write(uint32_t);
void	mipsNN_cp0_userlocal_write(void *);
#endif
#endif /* MIPSNN */

uint32_t mips3_cp0_count_read(void);
void	mips3_cp0_count_write(uint32_t);

uint32_t mips3_cp0_wired_read(void);
void	mips3_cp0_wired_write(uint32_t);
void	mips3_cp0_pg_mask_write(uint32_t);

#endif	/* MIPS3_PLUS */

/* 64-bit address space accessor for n32, n64 ABI */
/* 32-bit address space accessor for o32 ABI */
static inline uint8_t	mips_lbu(register_t addr) __unused;
static inline void	mips_sb(register_t addr, uint8_t val) __unused;
static inline uint16_t	mips_lhu(register_t addr) __unused;
static inline void	mips_sh(register_t addr, uint16_t val) __unused;
static inline uint32_t	mips_lwu(register_t addr) __unused;
static inline void	mips_sw(register_t addr, uint32_t val) __unused;
#ifdef MIPS3_64BIT
#if defined(__mips_o32)
uint64_t		mips3_ld(register_t addr);
void			mips3_sd(register_t addr, uint64_t val);
#else
static inline uint64_t	mips3_ld(register_t addr) __unused;
static inline void	mips3_sd(register_t addr, uint64_t val) __unused;
#endif
#endif

static inline uint8_t
mips_lbu(register_t addr)
{
	uint8_t rv;
#if defined(__mips_n32)
	__asm volatile("lbu\t%0, 0(%1)" : "=r"(rv) : "d"(addr));
#else
	rv = *(const volatile uint8_t *)addr;
#endif
	return rv;
}

static inline uint16_t
mips_lhu(register_t addr)
{
	uint16_t rv;
#if defined(__mips_n32)
	__asm volatile("lhu\t%0, 0(%1)" : "=r"(rv) : "d"(addr));
#else
	rv = *(const volatile uint16_t *)addr;
#endif
	return rv;
}

static inline uint32_t
mips_lwu(register_t addr)
{
	uint32_t rv;
#if defined(__mips_n32)
	__asm volatile("lwu\t%0, 0(%1)" : "=r"(rv) : "d"(addr));
#else
	rv = *(const volatile uint32_t *)addr;
#endif
	return (rv);
}

#if defined(MIPS3_64BIT) && !defined(__mips_o32)
static inline uint64_t
mips3_ld(register_t addr)
{
	uint64_t rv;
#if defined(__mips_n32)
	__asm volatile("ld\t%0, 0(%1)" : "=r"(rv) : "d"(addr));
#elif defined(_LP64)
	rv = *(const volatile uint64_t *)addr;
#else
#error unknown ABI
#endif
	return (rv);
}
#endif	/* MIPS3_64BIT && !__mips_o32 */

static inline void
mips_sb(register_t addr, uint8_t val)
{
#if defined(__mips_n32)
	__asm volatile("sb\t%1, 0(%0)" :: "d"(addr), "r"(val) : "memory");
#else
	*(volatile uint8_t *)addr = val;
#endif
}

static inline void
mips_sh(register_t addr, uint16_t val)
{
#if defined(__mips_n32)
	__asm volatile("sh\t%1, 0(%0)" :: "d"(addr), "r"(val) : "memory");
#else
	*(volatile uint16_t *)addr = val;
#endif
}

static inline void
mips_sw(register_t addr, uint32_t val)
{
#if defined(__mips_n32)
	__asm volatile("sw\t%1, 0(%0)" :: "d"(addr), "r"(val) : "memory");
#else
	*(volatile uint32_t *)addr = val;
#endif
}

#if defined(MIPS3_64BIT) && !defined(__mips_o32)
static inline void
mips3_sd(register_t addr, uint64_t val)
{
#if defined(__mips_n32)
	__asm volatile("sd\t%1, 0(%0)" :: "d"(addr), "r"(val) : "memory");
#else
	*(volatile uint64_t *)addr = val;
#endif
}
#endif	/* MIPS3_64BIT && !__mips_o32 */

/*
 * A vector with an entry for each mips-ISA-level dependent
 * locore function, and macros which jump through it.
 */
typedef struct  {
	void	(*ljv_cpu_switch_resume)(struct lwp *);
	intptr_t ljv_lwp_trampoline;
	void	(*ljv_wbflush)(void);
	tlb_asid_t (*ljv_tlb_get_asid)(void);
	void	(*ljv_tlb_set_asid)(tlb_asid_t pid);
	void	(*ljv_tlb_invalidate_asids)(tlb_asid_t, tlb_asid_t);
	void	(*ljv_tlb_invalidate_addr)(vaddr_t, tlb_asid_t);
	void	(*ljv_tlb_invalidate_globals)(void);
	void	(*ljv_tlb_invalidate_all)(void);
	u_int	(*ljv_tlb_record_asids)(u_long *, tlb_asid_t);
	int	(*ljv_tlb_update_addr)(vaddr_t, tlb_asid_t, pt_entry_t, bool);
	void	(*ljv_tlb_read_entry)(size_t, struct tlbmask *);
	void	(*ljv_tlb_write_entry)(size_t, const struct tlbmask *);
} mips_locore_jumpvec_t;

typedef struct {
	u_int	(*lav_atomic_cas_uint)(volatile u_int *, u_int, u_int);
	u_long	(*lav_atomic_cas_ulong)(volatile u_long *, u_long, u_long);
	int	(*lav_ucas_32)(volatile uint32_t *, uint32_t, uint32_t,
			       uint32_t *);
	int	(*lav_ucas_64)(volatile uint64_t *, uint64_t, uint64_t,
			       uint64_t *);
	void	(*lav_mutex_enter)(kmutex_t *);
	void	(*lav_mutex_exit)(kmutex_t *);
	void	(*lav_mutex_spin_enter)(kmutex_t *);
	void	(*lav_mutex_spin_exit)(kmutex_t *);
} mips_locore_atomicvec_t;

void	mips_set_wbflush(void (*)(void));
void	mips_wait_idle(void);

void	stacktrace(void);
void	logstacktrace(void);

struct cpu_info;
struct splsw;

struct locoresw {
	void		(*lsw_wbflush)(void);
	void		(*lsw_cpu_idle)(void);
	int		(*lsw_send_ipi)(struct cpu_info *, int);
	void		(*lsw_cpu_offline_md)(void);
	void		(*lsw_cpu_init)(struct cpu_info *);
	void		(*lsw_cpu_run)(struct cpu_info *);
	int		(*lsw_bus_error)(unsigned int);
};

struct mips_vmfreelist {
	paddr_t fl_start;
	paddr_t fl_end;
	int fl_freelist;
};

struct cpu_info *
	cpu_info_alloc(struct pmap_tlb_info *, cpuid_t, cpuid_t, cpuid_t,
	    cpuid_t);
void	cpu_attach_common(device_t, struct cpu_info *);
void	cpu_startup_common(void);

#ifdef MULTIPROCESSOR
void	cpu_hatch(struct cpu_info *ci);
void	cpu_trampoline(void);
void	cpu_halt(void);
void	cpu_halt_others(void);
void	cpu_pause(struct reg *);
void	cpu_pause_others(void);
void	cpu_resume(cpuid_t);
void	cpu_resume_others(void);
bool	cpu_is_paused(cpuid_t);
void	cpu_debug_dump(void);

extern kcpuset_t *cpus_running;
extern kcpuset_t *cpus_hatched;
extern kcpuset_t *cpus_paused;
extern kcpuset_t *cpus_resumed;
extern kcpuset_t *cpus_halted;
#endif

/* copy.S */
uint32_t mips_ufetch32(const void *);
int	mips_ustore32_isync(void *, uint32_t);

int32_t kfetch_32(volatile uint32_t *, uint32_t);

/* trap.c */
void	netintr(void);

/* mips_dsp.c */
void	dsp_init(void);
void	dsp_discard(lwp_t *);
void	dsp_load(void);
void	dsp_save(lwp_t *);
bool	dsp_used_p(const lwp_t *);
extern const pcu_ops_t mips_dsp_ops;

/* mips_fpu.c */
void	fpu_init(void);
void	fpu_discard(lwp_t *);
void	fpu_load(void);
void	fpu_save(lwp_t *);
bool	fpu_used_p(const lwp_t *);
extern const pcu_ops_t mips_fpu_ops;

/* mips_machdep.c */
void	dumpsys(void);
int	savectx(struct pcb *);
void	cpu_identify(device_t);

/* locore*.S */
int	badaddr(void *, size_t);
int	badaddr64(uint64_t, size_t);

/* vm_machdep.c */
int	ioaccess(vaddr_t, paddr_t, vsize_t);
int	iounaccess(vaddr_t, vsize_t);

/*
 * The "active" locore-function vector, and
 */
extern const mips_locore_atomicvec_t mips_llsc_locore_atomicvec;

extern mips_locore_atomicvec_t mips_locore_atomicvec;
extern mips_locore_jumpvec_t mips_locore_jumpvec;
extern struct locoresw mips_locoresw;

extern int mips_poolpage_vmfreelist;	/* freelist to allocate poolpages */
extern struct mips_options mips_options;

struct splsw;
struct mips_vmfreelist;
struct phys_ram_seg;

void	mips64r2_vector_init(const struct splsw *);
void	mips_vector_init(const struct splsw *, bool);
void	mips_init_msgbuf(void);
void	mips_init_lwp0_uarea(void);
void	mips_page_physload(vaddr_t, vaddr_t,
	    const struct phys_ram_seg *, size_t,
	    const struct mips_vmfreelist *, size_t);


/*
 * CPU identification, from PRID register.
 */
#define	MIPS_PRID_REV(x)	(((x) >>  0) & 0x00ff)
#define	MIPS_PRID_IMPL(x)	(((x) >>  8) & 0x00ff)

/* pre-MIPS32/64 */
#define	MIPS_PRID_RSVD(x)	(((x) >> 16) & 0xffff)
#define	MIPS_PRID_REV_MIN(x)	((MIPS_PRID_REV(x) >> 0) & 0x0f)
#define	MIPS_PRID_REV_MAJ(x)	((MIPS_PRID_REV(x) >> 4) & 0x0f)

/* MIPS32/64 */
#define	MIPS_PRID_CID(x)	(((x) >> 16) & 0x00ff)	/* Company ID */
#define	    MIPS_PRID_CID_PREHISTORIC	0x00	/* Not MIPS32/64 */
#define	    MIPS_PRID_CID_MTI		0x01	/* MIPS Technologies, Inc. */
#define	    MIPS_PRID_CID_BROADCOM	0x02	/* Broadcom */
#define	    MIPS_PRID_CID_ALCHEMY	0x03	/* Alchemy Semiconductor */
#define	    MIPS_PRID_CID_SIBYTE	0x04	/* SiByte */
#define	    MIPS_PRID_CID_SANDCRAFT	0x05	/* SandCraft */
#define	    MIPS_PRID_CID_PHILIPS	0x06	/* Philips */
#define	    MIPS_PRID_CID_TOSHIBA	0x07	/* Toshiba */
#define	    MIPS_PRID_CID_MICROSOFT	0x07	/* Microsoft also, sigh */
#define	    MIPS_PRID_CID_LSI		0x08	/* LSI */
				/*	0x09	unannounced */
				/*	0x0a	unannounced */
#define	    MIPS_PRID_CID_LEXRA		0x0b	/* Lexra */
#define	    MIPS_PRID_CID_RMI		0x0c	/* RMI / NetLogic */
#define	    MIPS_PRID_CID_CAVIUM	0x0d	/* Cavium */
#define	    MIPS_PRID_CID_INGENIC	0xe1
#define	MIPS_PRID_COPTS(x)	(((x) >> 24) & 0x00ff)	/* Company Options */

/*
 * Global variables used to communicate CPU type, and parameters
 * such as cache size, from locore to higher-level code (e.g., pmap).
 */
void mips_pagecopy(register_t dst, register_t src);
void mips_pagezero(register_t dst);

#ifdef __HAVE_MIPS_MACHDEP_CACHE_CONFIG
void mips_machdep_cache_config(void);
#endif

/*
 * trapframe argument passed to trap()
 */

#if 0
#define	TF_AST		0		/* really zero */
#define	TF_V0		_R_V0
#define	TF_V1		_R_V1
#define	TF_A0		_R_A0
#define	TF_A1		_R_A1
#define	TF_A2		_R_A2
#define	TF_A3		_R_A3
#define	TF_T0		_R_T0
#define	TF_T1		_R_T1
#define	TF_T2		_R_T2
#define	TF_T3		_R_T3

#if defined(__mips_n32) || defined(__mips_n64)
#define	TF_A4		_R_A4
#define	TF_A5		_R_A5
#define	TF_A6		_R_A6
#define	TF_A7		_R_A7
#else
#define	TF_T4		_R_T4
#define	TF_T5		_R_T5
#define	TF_T6		_R_T6
#define	TF_T7		_R_T7
#endif /* __mips_n32 || __mips_n64 */

#define	TF_TA0		_R_TA0
#define	TF_TA1		_R_TA1
#define	TF_TA2		_R_TA2
#define	TF_TA3		_R_TA3

#define	TF_T8		_R_T8
#define	TF_T9		_R_T9

#define	TF_RA		_R_RA
#define	TF_SR		_R_SR
#define	TF_MULLO	_R_MULLO
#define	TF_MULHI	_R_MULHI
#define	TF_EPC		_R_PC		/* may be changed by trap() call */

#define	TF_NREGS	(sizeof(struct reg) / sizeof(mips_reg_t))
#endif

struct trapframe {
	struct reg tf_registers;
#define	tf_regs	tf_registers.r_regs
	uint32_t   tf_ppl;		/* previous priority level */
	mips_reg_t tf_pad;		/* for 8 byte aligned */
};

CTASSERT(sizeof(struct trapframe) % (4*sizeof(mips_reg_t)) == 0);

/*
 * Stack frame for kernel traps. four args passed in registers.
 * A trapframe is pointed to by the 5th arg, and a dummy sixth argument
 * is used to avoid alignment problems
 */

struct kernframe {
#if defined(__mips_o32) || defined(__mips_o64)
	register_t cf_args[4 + 1];
#if defined(__mips_o32)
	register_t cf_pad;		/* (for 8 byte alignment) */
#endif
#endif
#if defined(__mips_n32) || defined(__mips_n64)
	register_t cf_pad[2];		/* for 16 byte alignment */
#endif
	register_t cf_sp;
	register_t cf_ra;
	struct trapframe cf_frame;
};

CTASSERT(sizeof(struct kernframe) % (2*sizeof(mips_reg_t)) == 0);

/*
 * PRocessor IDentity TABle
 */

struct pridtab {
	int	cpu_cid;
	int	cpu_pid;
	int	cpu_rev;	/* -1 == wildcard */
	int	cpu_copts;	/* -1 == wildcard */
	int	cpu_isa;	/* -1 == probed (mips32/mips64) */
	int	cpu_ntlb;	/* -1 == unknown, 0 == probed */
	int	cpu_flags;
	u_int	cpu_cp0flags;	/* presence of some cp0 regs */
	u_int	cpu_cidflags;	/* company-specific flags */
	const char	*cpu_name;
};

/*
 * bitfield defines for cpu_cp0flags
 */
#define	 MIPS_CP0FL_USE		__BIT(0)	/* use these flags */
#define	 MIPS_CP0FL_ECC		__BIT(1)
#define	 MIPS_CP0FL_CACHE_ERR	__BIT(2)
#define	 MIPS_CP0FL_EIRR	__BIT(3)
#define	 MIPS_CP0FL_EIMR	__BIT(4)
#define	 MIPS_CP0FL_EBASE	__BIT(5)  /* XXX probeable - shouldn't be hard coded */
#define	 MIPS_CP0FL_CONFIG	__BIT(6)  /* XXX defined - doesn't need to be hard coded */
#define	 MIPS_CP0FL_CONFIG1	__BIT(7)  /* XXX probeable - shouldn't be hard coded */
#define	 MIPS_CP0FL_CONFIG2	__BIT(8)  /* XXX probeable - shouldn't be hard coded */
#define	 MIPS_CP0FL_CONFIG3	__BIT(9)  /* XXX probeable - shouldn't be hard coded */
#define	 MIPS_CP0FL_CONFIG4	__BIT(10) /* XXX probeable - shouldn't be hard coded */
#define	 MIPS_CP0FL_CONFIG5	__BIT(11) /* XXX probeable - shouldn't be hard coded */
#define	 MIPS_CP0FL_CONFIG6	__BIT(12)
#define	 MIPS_CP0FL_CONFIG7	__BIT(13)

/*
 * cpu_cidflags defines, by company
 */
/*
 * RMI company-specific cpu_cidflags
 */
#define	MIPS_CIDFL_RMI_TYPE		__BITS(2,0)
# define  CIDFL_RMI_TYPE_XLR		0
# define  CIDFL_RMI_TYPE_XLS		1
# define  CIDFL_RMI_TYPE_XLP		2
#define	MIPS_CIDFL_RMI_THREADS_MASK	__BITS(6,3)
# define MIPS_CIDFL_RMI_THREADS_SHIFT	3
#define	MIPS_CIDFL_RMI_CORES_MASK	__BITS(10,7)
# define MIPS_CIDFL_RMI_CORES_SHIFT	7
# define LOG2_1	0
# define LOG2_2	1
# define LOG2_4	2
# define LOG2_8	3
# define MIPS_CIDFL_RMI_CPUS(ncores, nthreads)				\
		((LOG2_ ## ncores << MIPS_CIDFL_RMI_CORES_SHIFT)	\
		|(LOG2_ ## nthreads << MIPS_CIDFL_RMI_THREADS_SHIFT))
# define MIPS_CIDFL_RMI_NTHREADS(cidfl)					\
		(1 << (((cidfl) & MIPS_CIDFL_RMI_THREADS_MASK)		\
			>> MIPS_CIDFL_RMI_THREADS_SHIFT))
# define MIPS_CIDFL_RMI_NCORES(cidfl)					\
		(1 << (((cidfl) & MIPS_CIDFL_RMI_CORES_MASK)		\
			>> MIPS_CIDFL_RMI_CORES_SHIFT))
#define	MIPS_CIDFL_RMI_L2SZ_MASK	__BITS(14,11)
# define MIPS_CIDFL_RMI_L2SZ_SHIFT	11
# define RMI_L2SZ_256KB	 0
# define RMI_L2SZ_512KB  1
# define RMI_L2SZ_1MB    2
# define RMI_L2SZ_2MB    3
# define RMI_L2SZ_4MB    4
# define MIPS_CIDFL_RMI_L2(l2sz)					\
		(RMI_L2SZ_ ## l2sz << MIPS_CIDFL_RMI_L2SZ_SHIFT)
# define MIPS_CIDFL_RMI_L2SZ(cidfl)					\
		((256*1024) << (((cidfl) & MIPS_CIDFL_RMI_L2SZ_MASK)	\
			>> MIPS_CIDFL_RMI_L2SZ_SHIFT))
#endif	/* _KERNEL */
#endif /* !__ASSEMBLER__ */

#endif	/* _MIPS_LOCORE_H */