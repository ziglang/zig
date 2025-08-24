/*	$NetBSD: pmap.h,v 1.21 2020/03/14 14:05:43 ad Exp $	*/

/*
 * Copyright 2001 Wasabi Systems, Inc.
 * All rights reserved.
 *
 * Written by Eduardo Horvath and Simon Burge for Wasabi Systems, Inc.
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
 *      This product includes software developed for the NetBSD Project by
 *      Wasabi Systems, Inc.
 * 4. The name of Wasabi Systems, Inc. may not be used to endorse
 *    or promote products derived from this software without specific prior
 *    written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY WASABI SYSTEMS, INC. ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL WASABI SYSTEMS, INC
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/*-
 * Copyright (C) 1995, 1996 Wolfgang Solfrank.
 * Copyright (C) 1995, 1996 TooLs GmbH.
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

#ifndef	_IBM4XX_PMAP_H_
#define	_IBM4XX_PMAP_H_

#ifdef _LOCORE          
#error use assym.h instead
#endif

#if defined(_MODULE)
#error this file should not be included by loadable kernel modules
#endif

#include <powerpc/ibm4xx/tlb.h>

#define KERNEL_PID	1	/* TLB PID to use for kernel translation */

/*
 * A TTE is a 16KB or greater TLB entry w/size and endianness bits
 * stuffed in the (unused) low bits of the PA.
 */
#define	TTE_PA_MASK		0xffffc000
#define	TTE_RPN_MASK(sz)	(~((1 << (10 + 2 * (sz))) - 1))
#define	TTE_ENDIAN		0x00002000
#define	TTE_SZ_MASK		0x00001c00
#define	TTE_SZ_SHIFT		10

/* TTE_SZ_1K and TTE_SZ_4K are not allowed. */
#define	TTE_SZ_16K	(TLB_SIZE_16K << TTE_SZ_SHIFT)
#define	TTE_SZ_64K	(TLB_SIZE_64K << TTE_SZ_SHIFT)
#define	TTE_SZ_256K	(TLB_SIZE_256K << TTE_SZ_SHIFT)
#define	TTE_SZ_1M	(TLB_SIZE_1M << TTE_SZ_SHIFT)
#define	TTE_SZ_4M	(TLB_SIZE_4M << TTE_SZ_SHIFT)
#define	TTE_SZ_16M	(TLB_SIZE_16M << TTE_SZ_SHIFT)

#define	TTE_EX		TLB_EX
#define	TTE_WR		TLB_WR
#define TTE_ZSEL_MASK	TLB_ZSEL_MASK
#define TTE_ZSEL_SHFT	TLB_ZSEL_SHFT
#define TTE_W		TLB_W
#define TTE_I		TLB_I
#define TTE_M		TLB_M
#define TTE_G		TLB_G

#define	ZONE_PRIV	0
#define	ZONE_USER	1

#define	TTE_PA(p)	((p)&TTE_PA_MASK)
#define TTE_ZONE(z)	TLB_ZONE(z)

/*
 * Definitions for sizes of 1st and 2nd level page tables.
 *
 */
#define	PTSZ		(PAGE_SIZE / 4)
#define	PTMAP		(PTSZ * PAGE_SIZE)
#define	PTMSK		((PTMAP - 1) & ~(PGOFSET))

#define	PTIDX(v)	(((v) & PTMSK) >> PGSHIFT)

/* 2nd level tables map in any bits not mapped by 1st level tables. */
#define	STSZ		((0xffffffffU / (PAGE_SIZE * PTSZ)) + 1)
#define	STMAP		(0xffffffffU)
#define	STMSK		(~(PTMAP - 1))

#define	STIDX(v)	((v) >> (PGSHIFT + 12))


/* 
 * Extra flags to pass to pmap_enter() -- make sure they don't conflict
 * w/PMAP_CANFAIL or PMAP_WIRED
 */
#define	PME_NOCACHE	0x1000000
#define	PME_WRITETHROUG	0x2000000

/*
 * Pmap stuff
 */
struct pmap {
	volatile int pm_ctx;	/* PID to identify PMAP's entries in TLB */
	int pm_refs;			/* ref count */
	struct pmap_statistics pm_stats; /* pmap statistics */
	volatile u_int *pm_ptbl[STSZ];	/* Array of 64 pointers to page tables. */
};

#ifdef	_KERNEL
#define	PMAP_GROWKERNEL

#define	PMAP_ATTR_REF		0x1
#define	PMAP_ATTR_CHG		0x2

#define pmap_clear_modify(pg)	(pmap_check_attr((pg), PMAP_ATTR_CHG, 1))
#define	pmap_clear_reference(pg)(pmap_check_attr((pg), PMAP_ATTR_REF, 1))
#define	pmap_is_modified(pg)	(pmap_check_attr((pg), PMAP_ATTR_CHG, 0))
#define	pmap_is_referenced(pg)	(pmap_check_attr((pg), PMAP_ATTR_REF, 0))

#define	pmap_phys_address(x)		(x)

#define	pmap_resident_count(pmap)	((pmap)->pm_stats.resident_count)
#define	pmap_wired_count(pmap)		((pmap)->pm_stats.wired_count)

void pmap_unwire(struct pmap *pm, vaddr_t va);
void pmap_bootstrap(u_int kernelstart, u_int kernelend);
bool pmap_extract(struct pmap *, vaddr_t, paddr_t *);
bool pmap_check_attr(struct vm_page *, u_int, int);
void pmap_real_memory(paddr_t *, psize_t *);
int pmap_tlbmiss(vaddr_t va, int ctx);

static __inline bool
pmap_remove_all(struct pmap *pmap)
{
	/* Nothing. */
	return false;
}

int	ctx_alloc(struct pmap *);
void	ctx_free(struct pmap *);

#define PMAP_NEED_PROCWR
void pmap_procwr(struct proc *, vaddr_t, size_t);

/*
 * Alternate mapping hooks for pool pages.  Avoids thrashing the TLB.
 *
 * Note: This won't work if we have more memory than can be direct-mapped
 * VA==PA all at once.  But pmap_copy_page() and pmap_zero_page() will have
 * this problem, too.
 */
#define	PMAP_MAP_POOLPAGE(pa)	(pa)
#define	PMAP_UNMAP_POOLPAGE(pa)	(pa)

static __inline paddr_t vtophys(vaddr_t);

static __inline paddr_t
vtophys(vaddr_t va)
{
	paddr_t pa;

	/* XXX should check battable */

	if (pmap_extract(pmap_kernel(), va, &pa))
		return pa;
	return va;
}
#endif	/* _KERNEL */
#endif	/* _IBM4XX_PMAP_H_ */