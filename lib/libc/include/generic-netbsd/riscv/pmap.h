/* $NetBSD: pmap.h,v 1.13 2022/10/20 07:18:11 skrll Exp $ */

/*
 * Copyright (c) 2014, 2019, 2021 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Matt Thomas (of 3am Software Foundry), Maxime Villard, and
 * Nick Hudson.
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

#ifndef _RISCV_PMAP_H_
#define	_RISCV_PMAP_H_

#ifdef _KERNEL_OPT
#include "opt_modular.h"
#endif

#if !defined(_MODULE)

#include <sys/cdefs.h>
#include <sys/types.h>
#include <sys/pool.h>
#include <sys/evcnt.h>

#include <uvm/uvm_physseg.h>
#include <uvm/pmap/vmpagemd.h>

#include <riscv/pte.h>
#include <riscv/sysreg.h>

#define	PMAP_SEGTABSIZE	NPTEPG
#define	PMAP_PDETABSIZE	NPTEPG

#ifdef _LP64
#define	PTPSHIFT	3
/* This is SV48. */
//#define SEGLENGTH + SEGSHIFT + SEGSHIFT */

/* This is SV39. */
#define	XSEGSHIFT	(SEGSHIFT + SEGLENGTH)
#define	NBXSEG		(1ULL << XSEGSHIFT)
#define	XSEGOFSET	(NBXSEG - 1)		/* byte offset into xsegment */
#define	XSEGLENGTH	(PGSHIFT - 3)
#define	NXSEGPG		(1 << XSEGLENGTH)
#else
#define	PTPSHIFT	2
#define	XSEGSHIFT	SEGSHIFT
#endif

#define	SEGLENGTH	(PGSHIFT - PTPSHIFT)
#define	SEGSHIFT	(SEGLENGTH + PGSHIFT)
#define	NBSEG		(1 << SEGSHIFT)		/* bytes/segment */
#define	SEGOFSET	(NBSEG - 1)		/* byte offset into segment */

#define	KERNEL_PID	0

#define	PMAP_HWPAGEWALKER		1
#define	PMAP_TLB_MAX			1
#ifdef _LP64
#define	PMAP_INVALID_PDETAB_ADDRESS	((pmap_pdetab_t *)(VM_MIN_KERNEL_ADDRESS - PAGE_SIZE))
#define	PMAP_INVALID_SEGTAB_ADDRESS	((pmap_segtab_t *)(VM_MIN_KERNEL_ADDRESS - PAGE_SIZE))
#else
#define	PMAP_INVALID_PDETAB_ADDRESS	((pmap_pdetab_t *)0xdeadbeef)
#define	PMAP_INVALID_SEGTAB_ADDRESS	((pmap_segtab_t *)0xdeadbeef)
#endif
#define	PMAP_TLB_NUM_PIDS		(__SHIFTOUT_MASK(SATP_ASID) + 1)
#define	PMAP_TLB_BITMAP_LENGTH          PMAP_TLB_NUM_PIDS
#define	PMAP_TLB_FLUSH_ASID_ON_RESET	false

#define	pmap_phys_address(x)		(x)

#ifndef __BSD_PTENTRY_T__
#define	__BSD_PTENTRY_T__
#ifdef _LP64
#define	PRIxPTE         PRIx64
#else
#define	PRIxPTE         PRIx32
#endif
#endif /* __BSD_PTENTRY_T__ */

#define	PMAP_NEED_PROCWR
static inline void
pmap_procwr(struct proc *p, vaddr_t va, vsize_t len)
{
	__asm __volatile("fence\trw,rw; fence.i" ::: "memory");
}

#include <uvm/pmap/tlb.h>
#include <uvm/pmap/pmap_tlb.h>

#define	PMAP_GROWKERNEL
#define	PMAP_STEAL_MEMORY

#ifdef _KERNEL

#define	__HAVE_PMAP_MD
struct pmap_md {
	paddr_t md_ppn;
	pd_entry_t *md_pdetab;
};

struct vm_page *
	pmap_md_alloc_poolpage(int flags);
vaddr_t	pmap_md_map_poolpage(paddr_t, vsize_t);
void	pmap_md_unmap_poolpage(vaddr_t, vsize_t);
bool	pmap_md_direct_mapped_vaddr_p(vaddr_t);
bool	pmap_md_io_vaddr_p(vaddr_t);
paddr_t	pmap_md_direct_mapped_vaddr_to_paddr(vaddr_t);
vaddr_t	pmap_md_direct_map_paddr(paddr_t);
void	pmap_md_init(void);

void	pmap_md_xtab_activate(struct pmap *, struct lwp *);
void	pmap_md_xtab_deactivate(struct pmap *);
void	pmap_md_pdetab_init(struct pmap *);
bool	pmap_md_ok_to_steal_p(const uvm_physseg_t, size_t);

void	pmap_bootstrap(vaddr_t kstart, vaddr_t kend);

extern vaddr_t pmap_direct_base;
extern vaddr_t pmap_direct_end;
#define	PMAP_DIRECT_MAP(pa)	(pmap_direct_base + (pa))
#define	PMAP_DIRECT_UNMAP(va)	((paddr_t)(va) - pmap_direct_base)

#define	MEGAPAGE_TRUNC(x)	((x) & ~SEGOFSET)
#define	MEGAPAGE_ROUND(x)	MEGAPAGE_TRUNC((x) + SEGOFSET)

#ifdef __PMAP_PRIVATE

static inline bool
pmap_md_tlb_check_entry(void *ctx, vaddr_t va, tlb_asid_t asid, pt_entry_t pte)
{
        // TLB not walked and so not called.
        return false;
}

static inline void
pmap_md_page_syncicache(struct vm_page_md *mdpg, const kcpuset_t *kc)
{
	__asm __volatile("fence\trw,rw; fence.i" ::: "memory");
}

/*
 * Virtual Cache Alias helper routines.  Not a problem for RISCV CPUs.
 */
static inline bool
pmap_md_vca_add(struct vm_page_md *mdpg, vaddr_t va, pt_entry_t *nptep)
{
	return false;
}

static inline void
pmap_md_vca_remove(struct vm_page_md *mdpg, vaddr_t va)
{
}

static inline void
pmap_md_vca_clean(struct vm_page_md *mdpg, vaddr_t va, int op)
{
}

static inline size_t
pmap_md_tlb_asid_max(void)
{
	return PMAP_TLB_NUM_PIDS - 1;
}

#endif /* __PMAP_PRIVATE */
#endif /* _KERNEL */

#include <uvm/pmap/pmap.h>

#endif /* !_MODULE */

#if defined(MODULAR) || defined(_MODULE)
/*
 * Define a compatible vm_page_md so that struct vm_page is the same size
 * whether we are using modules or not.
 */
#ifndef __HAVE_VM_PAGE_MD
#define	__HAVE_VM_PAGE_MD

struct vm_page_md {
	uintptr_t mdpg_dummy[3];
};
__CTASSERT(sizeof(struct vm_page_md) == sizeof(uintptr_t)*3);

#endif /* !__HAVE_VM_PAGE_MD */

#endif /* MODULAR || _MODULE */

#endif /* !_RISCV_PMAP_H_ */