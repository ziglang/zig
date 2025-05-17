/*	$NetBSD: pmap.h,v 1.77 2022/10/26 07:35:19 skrll Exp $	*/

/*
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Ralph Campbell.
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
 *	@(#)pmap.h	8.1 (Berkeley) 6/10/93
 */

/*
 * Copyright (c) 1987 Carnegie-Mellon University
 *
 * This code is derived from software contributed to Berkeley by
 * Ralph Campbell.
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
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
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
 *	@(#)pmap.h	8.1 (Berkeley) 6/10/93
 */

#ifndef	_MIPS_PMAP_H_
#define	_MIPS_PMAP_H_

#ifdef _KERNEL_OPT
#include "opt_multiprocessor.h"
#include "opt_uvmhist.h"
#include "opt_cputype.h"
#endif

#include <sys/evcnt.h>
#include <sys/kcpuset.h>
#include <sys/kernhist.h>

#ifndef __BSD_PTENTRY_T__
#define	__BSD_PTENTRY_T__
typedef uint32_t pt_entry_t;
#define	PRIxPTE		PRIx32
#endif /* __BSD_PTENTRY_T__ */

#define	KERNEL_PID			0

#if defined(__PMAP_PRIVATE)
struct vm_page_md;

#include <mips/locore.h>
#include <mips/cache.h>

#define	PMAP_VIRTUAL_CACHE_ALIASES
#define	PMAP_INVALID_SEGTAB_ADDRESS	((pmap_segtab_t *)NULL)
#define	PMAP_TLB_NEED_SHOOTDOWN		1
#define	PMAP_TLB_FLUSH_ASID_ON_RESET	false
#if UPAGES > 1
#define	PMAP_TLB_WIRED_UPAGES		MIPS3_TLB_WIRED_UPAGES
#endif
#define	pmap_md_tlb_asid_max()		(MIPS_TLB_NUM_PIDS - 1)
#ifdef MULTIPROCESSOR
#define	PMAP_NO_PV_UNCACHED
#endif

/*
 * We need the pmap_segtab's to be aligned on MIPS*R2 so we can use the
 * EXT/INS instructions on their addresses.
 */
#if (MIPS32R2 + MIPS64R2 + MIPS64R2_RMIXL) > 0
#define	PMAP_SEGTAB_ALIGN __aligned(sizeof(void *)*NSEGPG) __section(".data1")
#endif

#include <uvm/uvm_physseg.h>

void	pmap_md_init(void);
void	pmap_md_icache_sync_all(void);
void	pmap_md_icache_sync_range_index(vaddr_t, vsize_t);
void	pmap_md_page_syncicache(struct vm_page_md *, const kcpuset_t *);
bool	pmap_md_vca_add(struct vm_page_md *, vaddr_t, pt_entry_t *);
void	pmap_md_vca_clean(struct vm_page_md *, int);
void	pmap_md_vca_remove(struct vm_page *, vaddr_t, bool, bool);
bool	pmap_md_ok_to_steal_p(const uvm_physseg_t, size_t);
bool	pmap_md_tlb_check_entry(void *, vaddr_t, tlb_asid_t, pt_entry_t);

static inline bool
pmap_md_virtual_cache_aliasing_p(void)
{
	return MIPS_CACHE_VIRTUAL_ALIAS;
}

static inline vsize_t
pmap_md_cache_prefer_mask(void)
{
	return MIPS_HAS_R4K_MMU ? mips_cache_info.mci_cache_prefer_mask : 0;
}

static inline void
pmap_md_xtab_activate(struct pmap *pm, struct lwp *l)
{

	/* nothing */
}

static inline void
pmap_md_xtab_deactivate(struct pmap *pm)
{

	/* nothing */
}

#endif /* __PMAP_PRIVATE */

// these use register_t so we can pass XKPHYS addresses to them on N32
bool	pmap_md_direct_mapped_vaddr_p(register_t);
paddr_t	pmap_md_direct_mapped_vaddr_to_paddr(register_t);
bool	pmap_md_io_vaddr_p(vaddr_t);

/*
 * Alternate mapping hooks for pool pages.  Avoids thrashing the TLB.
 */
vaddr_t pmap_md_map_poolpage(paddr_t, size_t);
paddr_t pmap_md_unmap_poolpage(vaddr_t, size_t);
struct vm_page *pmap_md_alloc_poolpage(int);

/*
 * Other hooks for the pool allocator.
 */
paddr_t	pmap_md_pool_vtophys(vaddr_t);
vaddr_t	pmap_md_pool_phystov(paddr_t);
#define	POOL_VTOPHYS(va)	pmap_md_pool_vtophys((vaddr_t)va)
#define	POOL_PHYSTOV(pa)	pmap_md_pool_phystov((paddr_t)pa)

#define pmap_md_direct_map_paddr(pa)	pmap_md_pool_phystov((paddr_t)pa)

struct tlbmask {
	vaddr_t	tlb_hi;
#ifdef __mips_o32
	uint32_t tlb_lo0;
	uint32_t tlb_lo1;
#else
	uint64_t tlb_lo0;
	uint64_t tlb_lo1;
#endif
	uint32_t tlb_mask;
};

#ifdef _LP64
#define	PMAP_SEGTABSIZE		NSEGPG
#else
#define	PMAP_SEGTABSIZE		(1 << (31 - SEGSHIFT))
#endif

#include <uvm/uvm_pmap.h>
#include <uvm/pmap/vmpagemd.h>
#include <uvm/pmap/pmap.h>
#include <uvm/pmap/pmap_pvt.h>
#include <uvm/pmap/pmap_tlb.h>
#include <uvm/pmap/pmap_synci.h>

#ifdef _KERNEL
/*
 * Select CCA to use for unmanaged pages.
 */
#define	PMAP_CCA_FOR_PA(pa)	CCA_UNCACHED		/* uncached */

#if defined(_MIPS_PADDR_T_64BIT) || defined(_LP64)
#define	PGC_NOCACHE	0x4000000000000000ULL
#define	PGC_PREFETCH	0x2000000000000000ULL
#endif

#if defined(__PMAP_PRIVATE)
#include <mips/pte.h>
#endif

/*
 * The user address space is 2Gb (0x0 - 0x80000000).
 * User programs are laid out in memory as follows:
 *			address
 *	USRTEXT		0x00001000
 *	USRDATA		USRTEXT + text_size
 *	USRSTACK	0x7FFFFFFF
 *
 * The user address space is mapped using a two level structure where
 * virtual address bits 30..22 are used to index into a segment table which
 * points to a page worth of PTEs (4096 page can hold 1024 PTEs).
 * Bits 21..12 are then used to index a PTE which describes a page within
 * a segment.
 *
 * The wired entries in the TLB will contain the following:
 *	0-1	(UPAGES)	for curproc user struct and kernel stack.
 *
 * Note: The kernel doesn't use the same data structures as user programs.
 * All the PTE entries are stored in a single array in Sysmap which is
 * dynamically allocated at boot time.
 */

#define	pmap_phys_address(x)	mips_ptob(x)

/*
 *	Bootstrap the system enough to run with virtual memory.
 */
void	pmap_bootstrap(void);
void	pmap_md_alloc_ephemeral_address_space(struct cpu_info *);
void	pmap_procwr(struct proc *, vaddr_t, size_t);
#define	PMAP_NEED_PROCWR

/*
 * pmap_prefer() helps reduce virtual-coherency exceptions in
 * the virtually-indexed cache on mips3 CPUs.
 */
#ifdef MIPS3_PLUS
#define	PMAP_PREFER(pa, va, sz, td)	pmap_prefer((pa), (va), (sz), (td))
void	pmap_prefer(vaddr_t, vaddr_t *, vsize_t, int);
#endif /* MIPS3_PLUS */

#define	PMAP_ENABLE_PMAP_KMPAGE	/* enable the PMAP_KMPAGE flag */

#ifdef MIPS64_SB1
/* uncached accesses are bad; all accesses should be cached (and coherent) */
#undef PMAP_PAGEIDLEZERO
#define	PMAP_PAGEIDLEZERO(pa)   (pmap_zero_page(pa), true)

int sbmips_cca_for_pa(paddr_t);

#undef PMAP_CCA_FOR_PA
#define	PMAP_CCA_FOR_PA(pa)	sbmips_cca_for_pa(pa)
#endif

#ifdef __HAVE_PMAP_PV_TRACK
struct pmap_page {
        struct vm_page_md       pp_md;
};

#define PMAP_PAGE_TO_MD(ppage)  (&((ppage)->pp_md))
#endif

#endif	/* _KERNEL */
#endif	/* _MIPS_PMAP_H_ */