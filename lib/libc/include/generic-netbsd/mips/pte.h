/*	$NetBSD: pte.h,v 1.27 2020/08/22 15:34:51 skrll Exp $	*/

/*-
 * Copyright (c) 1997 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe of the Numerical Aerospace Simulation Facility,
 * NASA Ames Research Center.
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

#ifndef  __MIPS_PTE_H__
#define	 __MIPS_PTE_H__

#include <mips/mips1_pte.h>
#include <mips/mips3_pte.h>

#define	PG_ASID	0x000000ff	/* Address space ID */

#ifndef _LOCORE
#ifndef __BSD_PTENTRY_T__
#define	__BSD_PTENTRY_T__
typedef uint32_t pt_entry_t;
#define	PRIxPTE		PRIx32
#endif

/*
 * Macros/inline functions to hide PTE format differences.
 */

#define	mips_pg_nv_bit()	(MIPS1_PG_NV)	/* same on mips1 and mips3 */


bool pmap_is_page_ro_p(struct pmap *pmap, vaddr_t, uint32_t);


/* MIPS1-only */
#if defined(MIPS1) && !defined(MIPS3_PLUS)
#define	mips_pg_v(entry)	((entry) & MIPS1_PG_V)
#define	mips_pg_wired(entry)	((entry) & MIPS1_PG_WIRED)

#define	mips_pg_m_bit()		(MIPS1_PG_D)
#define	mips_pg_rw_bit()	(MIPS1_PG_RW)	/* no RW bits for mips1 */
#define	mips_pg_ro_bit()	(MIPS1_PG_RO)
#define	mips_pg_ropage_bit()	(MIPS1_PG_RO)	/* XXX not MIPS1_PG_ROPAGE? */
#define	mips_pg_rwpage_bit()	(MIPS1_PG_RWPAGE)
#define	mips_pg_rwncpage_bit()	(MIPS1_PG_RWNCPAGE)
#define	mips_pg_cwpage_bit()	(MIPS1_PG_CWPAGE)
#define	mips_pg_cwncpage_bit()	(MIPS1_PG_CWNCPAGE)
#define	mips_pg_global_bit()	(MIPS1_PG_G)
#define	mips_pg_wired_bit()	(MIPS1_PG_WIRED)

#define	pte_to_paddr(pte)	MIPS1_PTE_TO_PADDR((pte))
#define	PAGE_IS_RDONLY(pte, va)	MIPS1_PAGE_IS_RDONLY((pte), (va))

#define	mips_tlbpfn_to_paddr(x)		mips1_tlbpfn_to_paddr((vaddr_t)(x))
#define	mips_paddr_to_tlbpfn(x)		mips1_paddr_to_tlbpfn((x))
#endif /* mips1 */


/* MIPS3 (or greater) only */
#if !defined(MIPS1) && defined(MIPS3_PLUS)
#define	mips_pg_v(entry)	((entry) & MIPS3_PG_V)
#define	mips_pg_wired(entry)	((entry) & MIPS3_PG_WIRED)

#define	mips_pg_m_bit()		(MIPS3_PG_D)
#define	mips_pg_rw_bit()	(MIPS3_PG_D)
#define	mips_pg_ro_bit()	(MIPS3_PG_RO)
#define	mips_pg_ropage_bit()	(MIPS3_PG_ROPAGE)
#define	mips_pg_rwpage_bit()	(MIPS3_PG_RWPAGE)
#define	mips_pg_rwncpage_bit()	(MIPS3_PG_RWNCPAGE)
#define	mips_pg_cwpage_bit()	(MIPS3_PG_CWPAGE)
#define	mips_pg_cwncpage_bit()	(MIPS3_PG_CWNCPAGE)
#define	mips_pg_global_bit()	(MIPS3_PG_G)
#define	mips_pg_wired_bit()	(MIPS3_PG_WIRED)

#define	pte_to_paddr(pte)	MIPS3_PTE_TO_PADDR((pte))
#define	PAGE_IS_RDONLY(pte, va)	MIPS3_PAGE_IS_RDONLY((pte), (va))

#define	mips_tlbpfn_to_paddr(x)		mips3_tlbpfn_to_paddr((vaddr_t)(x))
#define	mips_paddr_to_tlbpfn(x)		mips3_paddr_to_tlbpfn((x))
#endif /* mips3 */

/* MIPS1 and MIPS3 (or greater) */
#if defined(MIPS1) && defined(MIPS3_PLUS)

static __inline bool
    mips_pg_v(uint32_t entry),
    mips_pg_wired(uint32_t entry),
    PAGE_IS_RDONLY(uint32_t pte, vaddr_t va);

static __inline uint32_t
    mips_pg_wired_bit(void) __pure,
    mips_pg_m_bit(void) __pure,
    mips_pg_ro_bit(void) __pure,
    mips_pg_rw_bit(void) __pure,
    mips_pg_ropage_bit(void) __pure,
    mips_pg_cwpage_bit(void) __pure,
    mips_pg_rwpage_bit(void) __pure,
    mips_pg_global_bit(void) __pure;
static __inline paddr_t pte_to_paddr(pt_entry_t pte) __pure;
static __inline bool PAGE_IS_RDONLY(uint32_t pte, vaddr_t va) __pure;

static __inline paddr_t mips_tlbpfn_to_paddr(uint32_t pfn) __pure;
static __inline uint32_t mips_paddr_to_tlbpfn(paddr_t pa) __pure;


static __inline bool
mips_pg_v(uint32_t entry)
{
	if (MIPS_HAS_R4K_MMU)
		return (entry & MIPS3_PG_V) != 0;
	return (entry & MIPS1_PG_V) != 0;
}

static __inline bool
mips_pg_wired(uint32_t entry)
{
	if (MIPS_HAS_R4K_MMU)
		return (entry & MIPS3_PG_WIRED) != 0;
	return (entry & MIPS1_PG_WIRED) != 0;
}

static __inline uint32_t
mips_pg_m_bit(void)
{
	if (MIPS_HAS_R4K_MMU)
		return (MIPS3_PG_D);
	return (MIPS1_PG_D);
}

static __inline unsigned int
mips_pg_ro_bit(void)
{
	if (MIPS_HAS_R4K_MMU)
		return (MIPS3_PG_RO);
	return (MIPS1_PG_RO);
}

static __inline unsigned int
mips_pg_rw_bit(void)
{
	if (MIPS_HAS_R4K_MMU)
		return (MIPS3_PG_D);
	return (MIPS1_PG_RW);
}

static __inline unsigned int
mips_pg_ropage_bit(void)
{
	if (MIPS_HAS_R4K_MMU)
		return (MIPS3_PG_ROPAGE);
	return (MIPS1_PG_RO);
}

static __inline unsigned int
mips_pg_rwpage_bit(void)
{
	if (MIPS_HAS_R4K_MMU)
		return (MIPS3_PG_RWPAGE);
	return (MIPS1_PG_RWPAGE);
}

static __inline unsigned int
mips_pg_cwpage_bit(void)
{
	if (MIPS_HAS_R4K_MMU)
		return (MIPS3_PG_CWPAGE);
	return (MIPS1_PG_CWPAGE);
}


static __inline unsigned int
mips_pg_global_bit(void)
{
	if (MIPS_HAS_R4K_MMU)
		return (MIPS3_PG_G);
	return (MIPS1_PG_G);
}

static __inline unsigned int
mips_pg_wired_bit(void)
{
	if (MIPS_HAS_R4K_MMU)
		return (MIPS3_PG_WIRED);
	return (MIPS1_PG_WIRED);
}

static __inline paddr_t
pte_to_paddr(pt_entry_t pte)
{
	if (MIPS_HAS_R4K_MMU)
		return (MIPS3_PTE_TO_PADDR(pte));
	return (MIPS1_PTE_TO_PADDR(pte));
}

static __inline bool
PAGE_IS_RDONLY(uint32_t pte, vaddr_t va)
{
	if (MIPS_HAS_R4K_MMU)
		return (MIPS3_PAGE_IS_RDONLY(pte, va));
	return (MIPS1_PAGE_IS_RDONLY(pte, va));
}

static __inline paddr_t
mips_tlbpfn_to_paddr(uint32_t pfn)
{
	if (MIPS_HAS_R4K_MMU)
		return (mips3_tlbpfn_to_paddr(pfn));
	return (mips1_tlbpfn_to_paddr(pfn));
}

static __inline uint32_t
mips_paddr_to_tlbpfn(paddr_t pa)
{
	if (MIPS_HAS_R4K_MMU)
		return (mips3_paddr_to_tlbpfn(pa));
	return (mips1_paddr_to_tlbpfn(pa));
}
#endif

#endif /* ! _LOCORE */

#if defined(_KERNEL) && !defined(_LOCORE)
#define	MIPS_MMU(X)	(MIPS_HAS_R4K_MMU ? MIPS3_##X : MIPS1_##X)
static inline bool
pte_valid_p(pt_entry_t pte)
{
	return (pte & MIPS_MMU(PG_V)) != 0;
}

static inline bool
pte_modified_p(pt_entry_t pte)
{
	return (pte & MIPS_MMU(PG_D)) != 0;
}

static inline bool
pte_global_p(pt_entry_t pte)
{
	return (pte & MIPS_MMU(PG_G)) != 0;
}

static inline bool
pte_wired_p(pt_entry_t pte)
{
	return (pte & MIPS_MMU(PG_WIRED)) != 0;
}

static inline pt_entry_t
pte_wire_entry(pt_entry_t pte)
{
	return pte | MIPS_MMU(PG_WIRED);
}

static inline pt_entry_t
pte_unwire_entry(pt_entry_t pte)
{
	return pte & ~MIPS_MMU(PG_WIRED);
}

static inline uint32_t
pte_value(pt_entry_t pte)
{
	return pte;
}

static inline bool
pte_readonly_p(pt_entry_t pte)
{
	return (pte & MIPS_MMU(PG_RO)) != 0;
}

static inline bool
pte_cached_p(pt_entry_t pte)
{
	if (MIPS_HAS_R4K_MMU) {
		return MIPS3_PG_TO_CCA(pte) == MIPS3_PG_TO_CCA(mips_options.mips3_pg_cached);
	} else {
		return (pte & MIPS1_PG_N) == 0;
	}
}

static inline bool
pte_deferred_exec_p(pt_entry_t pte)
{
	return false;
}

static inline pt_entry_t
pte_nv_entry(bool kernel_p)
{
	__CTASSERT(MIPS1_PG_NV == MIPS3_PG_NV);
	__CTASSERT(MIPS1_PG_NV == 0);
	return (kernel_p && MIPS_HAS_R4K_MMU) ? MIPS3_PG_G : 0;
}

static inline pt_entry_t
pte_prot_downgrade(pt_entry_t pte, vm_prot_t prot)
{
	const uint32_t ro_bit = MIPS_MMU(PG_RO);
	const uint32_t rw_bit = MIPS_MMU(PG_D);

	return (pte & ~(ro_bit|rw_bit))
	    | ((prot & VM_PROT_WRITE) ? rw_bit : ro_bit);
}

static inline pt_entry_t
pte_prot_nowrite(pt_entry_t pte)
{
	return pte & ~MIPS_MMU(PG_D);
}

static inline pt_entry_t
pte_cached_change(pt_entry_t pte, bool cached)
{
	if (MIPS_HAS_R4K_MMU) {
		pte &= ~MIPS3_PG_CACHEMODE;
		pte |= (cached ? MIPS3_PG_CACHED : MIPS3_PG_UNCACHED);
	}
	return pte;
}

static inline void
pte_set(pt_entry_t *ptep, pt_entry_t pte)
{
	*ptep = pte;
}

#ifdef __PMAP_PRIVATE
struct vm_page_md;

static inline pt_entry_t
pte_make_kenter_pa(paddr_t pa, struct vm_page_md *mdpg, vm_prot_t prot,
    u_int flags)
{
	pt_entry_t pte;
	if (MIPS_HAS_R4K_MMU) {
		pte = mips3_paddr_to_tlbpfn(pa)
		    | ((prot & VM_PROT_WRITE) ? MIPS3_PG_D : MIPS3_PG_RO)
		    | ((flags & PMAP_NOCACHE) ? MIPS3_PG_UNCACHED : MIPS3_PG_CACHED)
		    | MIPS3_PG_WIRED | MIPS3_PG_V | MIPS3_PG_G;
	} else {
		pte = mips1_paddr_to_tlbpfn(pa)
		    | ((prot & VM_PROT_WRITE) ? MIPS1_PG_D : MIPS1_PG_RO)
		    | ((flags & PMAP_NOCACHE) ? MIPS1_PG_N : 0)
		    | MIPS1_PG_WIRED | MIPS1_PG_V | MIPS1_PG_G;
	}
	return pte;
}

static inline pt_entry_t
pte_make_enter(paddr_t pa, const struct vm_page_md *mdpg, vm_prot_t prot,
    u_int flags, bool is_kernel_pmap_p)
{
	pt_entry_t pte;
#if defined(_MIPS_PADDR_T_64BIT) || defined(_LP64)
	const bool cached = (flags & PMAP_NOCACHE) == 0
	    && (pa & PGC_NOCACHE) == 0;
	const bool prefetch = (pa & PGC_PREFETCH) != 0;

	pa &= ~(PGC_NOCACHE|PGC_PREFETCH);
#endif

#if defined(cobalt) || defined(newsmips) || defined(pmax) /* otherwise ok */
	/* this is not error in general. */
	KASSERTMSG((pa & 0x80000000) == 0, "%#"PRIxPADDR, pa);
#endif

	if (mdpg != NULL) {
		if ((prot & VM_PROT_WRITE) == 0) {
			/*
			 * If page is not yet referenced, we could emulate this
			 * by not setting the page valid, and setting the
			 * referenced status in the TLB fault handler, similar
			 * to how page modified status is done for UTLBmod
			 * exceptions.
			 */
			pte = mips_pg_ropage_bit();
#if defined(_MIPS_PADDR_T_64BIT) || defined(_LP64)
		} else if (cached == false) {
			if (VM_PAGEMD_MODIFIED_P(mdpg)) {
				pte = mips_pg_rwncpage_bit();
			} else {
				pte = mips_pg_cwncpage_bit();
			}
#endif
		} else {
			if (VM_PAGEMD_MODIFIED_P(mdpg)) {
				pte = mips_pg_rwpage_bit();
			} else {
				pte = mips_pg_cwpage_bit();
			}
		}
	} else if (MIPS_HAS_R4K_MMU) {
		/*
		 * Assumption: if it is not part of our managed memory
		 * then it must be device memory which may be volatile.
		 */
		u_int cca = PMAP_CCA_FOR_PA(pa);
#if defined(_MIPS_PADDR_T_64BIT) || defined(_LP64)
		if (prefetch)
			cca = mips_options.mips3_cca_devmem;
#endif
		pte = MIPS3_PG_IOPAGE(cca) & ~MIPS3_PG_G;
	} else if (prot & VM_PROT_WRITE) {
		pte = MIPS1_PG_N | MIPS1_PG_D;
	} else {
		pte = MIPS1_PG_N | MIPS1_PG_RO;
	}

	if (MIPS_HAS_R4K_MMU) {
		pte |= mips3_paddr_to_tlbpfn(pa)
		    | (is_kernel_pmap_p ? MIPS3_PG_G : 0);
	} else {
		pte |= mips1_paddr_to_tlbpfn(pa)
		    | MIPS1_PG_V
		    | (is_kernel_pmap_p ? MIPS1_PG_G : 0);
	}

	return pte;
}
#endif /* __PMAP_PRIVATE */

#endif	/* defined(_KERNEL) && !defined(_LOCORE) */
#endif /* __MIPS_PTE_H__ */