/* $NetBSD: pmap.h,v 1.57 2022/11/03 09:04:56 skrll Exp $ */

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

#ifndef _AARCH64_PMAP_H_
#define _AARCH64_PMAP_H_

#ifdef __aarch64__

#ifdef _KERNEL
#ifdef _KERNEL_OPT
#include "opt_kasan.h"
#include "opt_pmap.h"
#endif

#include <sys/types.h>
#include <sys/pool.h>
#include <sys/queue.h>

#include <uvm/uvm_pglist.h>

#include <aarch64/armreg.h>
#include <aarch64/pte.h>

#define	PMAP_TLB_MAX			1
#if PMAP_TLB_MAX > 1
#define	PMAP_TLB_NEED_SHOOTDOWN		1
#endif

#define	PMAP_TLB_FLUSH_ASID_ON_RESET	true

/* Maximum number of ASIDs. Some CPUs have less.*/
#define	PMAP_TLB_NUM_PIDS		65536
#define	PMAP_TLB_BITMAP_LENGTH		PMAP_TLB_NUM_PIDS
#define	cpu_set_tlb_info(ci, ti)        ((void)((ci)->ci_tlb_info = (ti)))
#if PMAP_TLB_MAX > 1
#define	cpu_tlb_info(ci)		((ci)->ci_tlb_info)
#else
#define	cpu_tlb_info(ci)		(&pmap_tlb0_info)
#endif

static inline tlb_asid_t
pmap_md_tlb_asid_max(void)
{
	switch (__SHIFTOUT(reg_id_aa64mmfr0_el1_read(), ID_AA64MMFR0_EL1_ASIDBITS)) {
	case ID_AA64MMFR0_EL1_ASIDBITS_8BIT:
		return (1U << 8) - 1;
	case ID_AA64MMFR0_EL1_ASIDBITS_16BIT:
		return (1U << 16) - 1;
	default:
		return 0;
	}
}

#include <uvm/pmap/tlb.h>
#include <uvm/pmap/pmap_tlb.h>

#define KERNEL_PID		0	/* The kernel uses ASID 0 */


/* memory attributes are configured MAIR_EL1 in locore */
#define LX_BLKPAG_ATTR_NORMAL_WB	__SHIFTIN(0, LX_BLKPAG_ATTR_INDX)
#define LX_BLKPAG_ATTR_NORMAL_NC	__SHIFTIN(1, LX_BLKPAG_ATTR_INDX)
#define LX_BLKPAG_ATTR_NORMAL_WT	__SHIFTIN(2, LX_BLKPAG_ATTR_INDX)
#define LX_BLKPAG_ATTR_DEVICE_MEM	__SHIFTIN(3, LX_BLKPAG_ATTR_INDX)
#define LX_BLKPAG_ATTR_DEVICE_MEM_NP	__SHIFTIN(4, LX_BLKPAG_ATTR_INDX)
#define LX_BLKPAG_ATTR_MASK		LX_BLKPAG_ATTR_INDX

#define lxpde_pa(pde)		((paddr_t)((pde) & LX_TBL_PA))
#define lxpde_valid(pde)	(((pde) & LX_VALID) == LX_VALID)
#define l0pde_pa(pde)		lxpde_pa(pde)
#define l0pde_index(v)		(((vaddr_t)(v) & L0_ADDR_BITS) >> L0_SHIFT)
#define l0pde_valid(pde)	lxpde_valid(pde)
/* l0pte always contains table entries */

#define l1pde_pa(pde)		lxpde_pa(pde)
#define l1pde_index(v)		(((vaddr_t)(v) & L1_ADDR_BITS) >> L1_SHIFT)
#define l1pde_valid(pde)	lxpde_valid(pde)
#define l1pde_is_block(pde)	(((pde) & LX_TYPE) == LX_TYPE_BLK)
#define l1pde_is_table(pde)	(((pde) & LX_TYPE) == LX_TYPE_TBL)

#define l2pde_pa(pde)		lxpde_pa(pde)
#define l2pde_index(v)		(((vaddr_t)(v) & L2_ADDR_BITS) >> L2_SHIFT)
#define l2pde_valid(pde)	lxpde_valid(pde)
#define l2pde_is_block(pde)	(((pde) & LX_TYPE) == LX_TYPE_BLK)
#define l2pde_is_table(pde)	(((pde) & LX_TYPE) == LX_TYPE_TBL)

#define l3pte_pa(pde)		lxpde_pa(pde)
#define l3pte_executable(pde,user)	\
    (((pde) & ((user) ? LX_BLKPAG_UXN : LX_BLKPAG_PXN)) == 0)
#define l3pte_readable(pde)	((pde) & LX_BLKPAG_AF)
#define l3pte_writable(pde)	\
    (((pde) & (LX_BLKPAG_AF | LX_BLKPAG_AP)) == (LX_BLKPAG_AF | LX_BLKPAG_AP_RW))
#define l3pte_index(v)		(((vaddr_t)(v) & L3_ADDR_BITS) >> L3_SHIFT)
#define l3pte_valid(pde)	lxpde_valid(pde)
#define l3pte_is_page(pde)	(((pde) & LX_TYPE) == L3_TYPE_PAG)

pd_entry_t *pmap_l0table(struct pmap *);
void pmap_bootstrap(vaddr_t, vaddr_t);
bool pmap_fault_fixup(struct pmap *, vaddr_t, vm_prot_t, bool user);

bool	pmap_extract_coherency(pmap_t, vaddr_t, paddr_t *, bool *);


/* change attribute of kernel segment */
static inline pt_entry_t
pmap_kvattr(pt_entry_t *ptep, vm_prot_t prot)
{
	pt_entry_t pte = *ptep;
	const pt_entry_t opte = pte;

	pte &= ~(LX_BLKPAG_AF | LX_BLKPAG_AP);
	switch (prot & (VM_PROT_READ | VM_PROT_WRITE)) {
	case 0:
		break;
	case VM_PROT_READ:
		pte |= LX_BLKPAG_AF | LX_BLKPAG_AP_RO;
		break;
	case VM_PROT_WRITE:
	case VM_PROT_READ | VM_PROT_WRITE:
		pte |= LX_BLKPAG_AF | LX_BLKPAG_AP_RW;
		break;
	}

	if ((prot & VM_PROT_EXECUTE) == 0) {
		pte |= LX_BLKPAG_PXN;
	} else {
		pte |= LX_BLKPAG_AF;
		pte &= ~LX_BLKPAG_PXN;
	}

	*ptep = pte;

	return opte;
}

/* devmap */
struct pmap_devmap {
	vaddr_t pd_va;		/* virtual address */
	paddr_t pd_pa;		/* physical address */
	psize_t pd_size;	/* size of region */
	vm_prot_t pd_prot;	/* protection code */
	u_int pd_flags;		/* flags for pmap_kenter_pa() */
};

void pmap_devmap_register(const struct pmap_devmap *);
void pmap_devmap_bootstrap(vaddr_t, const struct pmap_devmap *);
const struct pmap_devmap *pmap_devmap_find_pa(paddr_t, psize_t);
const struct pmap_devmap *pmap_devmap_find_va(vaddr_t, vsize_t);
vaddr_t pmap_devmap_phystov(paddr_t);
paddr_t pmap_devmap_vtophys(paddr_t);

#define L1_TRUNC_BLOCK(x)	((x) & L1_FRAME)
#define L1_ROUND_BLOCK(x)	L1_TRUNC_BLOCK((x) + L1_SIZE - 1)
#define L2_TRUNC_BLOCK(x)	((x) & L2_FRAME)
#define L2_ROUND_BLOCK(x)	L2_TRUNC_BLOCK((x) + L2_SIZE - 1)
#define L3_TRUNC_BLOCK(x)	((x) & L3_FRAME)
#define L3_ROUND_BLOCK(x)	L3_TRUNC_BLOCK((x) + L3_SIZE - 1)

#define DEVMAP_ALIGN(x)		L3_TRUNC_BLOCK((x))
#define DEVMAP_SIZE(x)		L3_ROUND_BLOCK((x))

#define	DEVMAP_ENTRY(va, pa, sz)				\
	{							\
		.pd_va = DEVMAP_ALIGN(va),			\
		.pd_pa = DEVMAP_ALIGN(pa),			\
		.pd_size = DEVMAP_SIZE(sz),			\
		.pd_prot = VM_PROT_READ | VM_PROT_WRITE,	\
		.pd_flags = PMAP_DEV				\
	}
#define	DEVMAP_ENTRY_END	{ 0 }

/* Hooks for the pool allocator */
paddr_t vtophys(vaddr_t);

/* mmap cookie and flags */
#define AARCH64_MMAP_FLAG_SHIFT		(64 - PGSHIFT)
#define AARCH64_MMAP_FLAG_MASK		0xf
#define AARCH64_MMAP_WRITEBACK		0UL
#define AARCH64_MMAP_NOCACHE		1UL
#define AARCH64_MMAP_WRITECOMBINE	2UL
#define AARCH64_MMAP_DEVICE		3UL

#define ARM_MMAP_MASK			__BITS(63, AARCH64_MMAP_FLAG_SHIFT)
#define ARM_MMAP_WRITECOMBINE		__SHIFTIN(AARCH64_MMAP_WRITECOMBINE, ARM_MMAP_MASK)
#define ARM_MMAP_WRITEBACK		__SHIFTIN(AARCH64_MMAP_WRITEBACK, ARM_MMAP_MASK)
#define ARM_MMAP_NOCACHE		__SHIFTIN(AARCH64_MMAP_NOCACHE, ARM_MMAP_MASK)
#define ARM_MMAP_DEVICE			__SHIFTIN(AARCH64_MMAP_DEVICE, ARM_MMAP_MASK)

#define	PMAP_PTE			0x10000000 /* kenter_pa */
#define	PMAP_DEV			0x20000000 /* kenter_pa */
#define	PMAP_DEV_NP			0x40000000 /* kenter_pa */
#define	PMAP_DEV_MASK			(PMAP_DEV | PMAP_DEV_NP)

static inline u_int
aarch64_mmap_flags(paddr_t mdpgno)
{
	u_int nflag, pflag;

	/*
	 * aarch64 arch has 5 memory attributes defined:
	 *
	 *  WriteBack      - write back cache
	 *  WriteThru      - write through cache
	 *  NoCache        - no cache
	 *  Device(nGnRE)  - no Gathering, no Reordering, Early write ack
	 *  Device(nGnRnE) - no Gathering, no Reordering, no Early write ack
	 *
	 * but pmap has PMAP_{NOCACHE,WRITE_COMBINE,WRITE_BACK} flags.
	 */

	nflag = (mdpgno >> AARCH64_MMAP_FLAG_SHIFT) & AARCH64_MMAP_FLAG_MASK;
	switch (nflag) {
	case AARCH64_MMAP_DEVICE:
		pflag = PMAP_DEV;
		break;
	case AARCH64_MMAP_WRITECOMBINE:
		pflag = PMAP_WRITE_COMBINE;
		break;
	case AARCH64_MMAP_WRITEBACK:
		pflag = PMAP_WRITE_BACK;
		break;
	case AARCH64_MMAP_NOCACHE:
	default:
		pflag = PMAP_NOCACHE;
		break;
	}
	return pflag;
}

#define pmap_phys_address(pa)		aarch64_ptob((pa))
#define pmap_mmap_flags(ppn)		aarch64_mmap_flags((ppn))

void pmap_bootstrap(vaddr_t, vaddr_t);
bool pmap_fault_fixup(struct pmap *, vaddr_t, vm_prot_t, bool user);

pd_entry_t *pmapboot_pagealloc(void);
void pmapboot_enter(vaddr_t, paddr_t, psize_t, psize_t, pt_entry_t,
    void (*pr)(const char *, ...) __printflike(1, 2));
void pmapboot_enter_range(vaddr_t, paddr_t, psize_t, pt_entry_t,
    void (*)(const char *, ...) __printflike(1, 2));
int pmapboot_protect(vaddr_t, vaddr_t, vm_prot_t);

#if defined(DDB)
void pmap_db_pte_print(pt_entry_t, int, void (*)(const char *, ...) __printflike(1, 2));
void pmap_db_pteinfo(vaddr_t, void (*)(const char *, ...) __printflike(1, 2));
void pmap_db_ttbrdump(bool, vaddr_t, void (*)(const char *, ...) __printflike(1, 2));
#endif

#define LX_BLKPAG_OS_WIRED		LX_BLKPAG_OS_2
#define LX_BLKPAG_OS_BOOT		LX_BLKPAG_OS_3

#define PMAP_PTE_OS2	"wired"
#define PMAP_PTE_OS3	"boot"

#if defined(PMAP_MI)
#include <aarch64/pmap_machdep.h>
#else

#define PMAP_NEED_PROCWR
#define PMAP_GROWKERNEL
#define PMAP_STEAL_MEMORY

#define __HAVE_VM_PAGE_MD
#define __HAVE_PMAP_PV_TRACK	1

struct pmap {
	kmutex_t pm_lock;
	struct pool *pm_pvpool;
	pd_entry_t *pm_l0table;			/* L0 table: 512G*512 */
	paddr_t pm_l0table_pa;

	LIST_HEAD(, vm_page) pm_vmlist;		/* for L[0123] tables */
	LIST_HEAD(, pv_entry) pm_pvlist;	/* all pv of this process */

	struct pmap_statistics pm_stats;
	unsigned int pm_refcnt;
	unsigned int pm_idlepdp;

	kcpuset_t *pm_onproc;
	kcpuset_t *pm_active;

	struct pmap_asid_info pm_pai[PMAP_TLB_MAX];
	bool pm_activated;
};

static inline paddr_t
pmap_l0pa(struct pmap *pm)
{
	return pm->pm_l0table_pa;
}


/*
 * should be kept <=32 bytes sized to reduce memory consumption & cache misses,
 * but it doesn't...
 */
struct pv_entry {
	struct pv_entry *pv_next;
	struct pmap *pv_pmap;
	vaddr_t pv_va;	/* for embedded entry (pp_pv) also includes flags */
	void *pv_ptep;	/* pointer for fast pte lookup */
	LIST_ENTRY(pv_entry) pv_proc;	/* belonging to the process */
};

struct pmap_page {
	kmutex_t pp_pvlock;
	struct pv_entry pp_pv;
};

/* try to keep vm_page at or under 128 bytes to reduce cache misses */
struct vm_page_md {
	struct pmap_page mdpg_pp;
};
/* for page descriptor page only */
#define	mdpg_ptep_parent	mdpg_pp.pp_pv.pv_ptep

#define VM_MDPAGE_INIT(pg)					\
	do {							\
		PMAP_PAGE_INIT(&(pg)->mdpage.mdpg_pp);		\
	} while (/*CONSTCOND*/ 0)

#define PMAP_PAGE_INIT(pp)						\
	do {								\
		mutex_init(&(pp)->pp_pvlock, MUTEX_NODEBUG, IPL_NONE);	\
		(pp)->pp_pv.pv_next = NULL;				\
		(pp)->pp_pv.pv_pmap = NULL;				\
		(pp)->pp_pv.pv_va = 0;					\
		(pp)->pp_pv.pv_ptep = NULL;				\
	} while (/*CONSTCOND*/ 0)

/* saved permission bit for referenced/modified emulation */
#define LX_BLKPAG_OS_READ		LX_BLKPAG_OS_0
#define LX_BLKPAG_OS_WRITE		LX_BLKPAG_OS_1
#define LX_BLKPAG_OS_RWMASK		(LX_BLKPAG_OS_WRITE | LX_BLKPAG_OS_READ)

#define PMAP_PTE_OS0	"read"
#define PMAP_PTE_OS1	"write"

#define VTOPHYS_FAILED			((paddr_t)-1L)	/* POOL_PADDR_INVALID */
#define POOL_VTOPHYS(va)		vtophys((vaddr_t) (va))

#ifndef KASAN
#define PMAP_MAP_POOLPAGE(pa)		AARCH64_PA_TO_KVA(pa)
#define PMAP_UNMAP_POOLPAGE(va)		AARCH64_KVA_TO_PA(va)

#define PMAP_DIRECT
static __inline int
pmap_direct_process(paddr_t pa, voff_t pgoff, size_t len,
    int (*process)(void *, size_t, void *), void *arg)
{
	vaddr_t va = AARCH64_PA_TO_KVA(pa);

	return process((void *)(va + pgoff), len, arg);
}
#endif

/* l3pte contains always page entries */
static inline uint64_t
pte_value(pt_entry_t pte)
{
	return pte;
}

static inline bool
pte_valid_p(pt_entry_t pte)
{
	return l3pte_valid(pte);
}

pt_entry_t *kvtopte(vaddr_t);

#define pmap_update(pmap)		((void)0)
#define pmap_copy(dp,sp,d,l,s)		((void)0)
#define pmap_wired_count(pmap)		((pmap)->pm_stats.wired_count)
#define pmap_resident_count(pmap)	((pmap)->pm_stats.resident_count)

struct pmap *
	pmap_efirt(void);
void	pmap_activate_efirt(void);
void	pmap_deactivate_efirt(void);

void	pmap_procwr(struct proc *, vaddr_t, int);
void	pmap_icache_sync_range(pmap_t, vaddr_t, vaddr_t);

void	pmap_pv_init(void);
void	pmap_pv_track(paddr_t, psize_t);
void	pmap_pv_untrack(paddr_t, psize_t);
void	pmap_pv_protect(paddr_t, vm_prot_t);

#define	PMAP_MAPSIZE1	L2_SIZE

/* for ddb */
void pmap_db_pmap_print(struct pmap *, void (*)(const char *, ...) __printflike(1, 2));
void pmap_db_mdpg_print(struct vm_page *, void (*)(const char *, ...) __printflike(1, 2));

#endif	/* !PMAP_MI */

#endif /* _KERNEL */

#elif defined(__arm__)

#include <arm/pmap.h>

#endif /* __arm__/__aarch64__ */

#endif /* !_AARCH64_PMAP_ */