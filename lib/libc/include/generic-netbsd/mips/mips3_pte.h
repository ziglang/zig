/*	$NetBSD: mips3_pte.h,v 1.31 2020/08/17 03:19:35 mrg Exp $	*/

/*
 * Copyright (c) 1988 University of Utah.
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * the Systems Programming Group of the University of Utah Computer
 * Science Department and Ralph Campbell.
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
 * from: Utah Hdr: pte.h 1.11 89/09/03
 *
 *	from: @(#)pte.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _MIPS_MIPS3_PTE_H_
#define	_MIPS_MIPS3_PTE_H_

/*
 * R4000 hardware page table entry
 */

#ifndef _LOCORE
#if 0
struct mips3_pte {
#if BYTE_ORDER == BIG_ENDIAN
unsigned int	pg_prot:2,		/* SW: access control */
		pg_pfnum:24,		/* HW: core page frame number or 0 */
		pg_attr:3,		/* HW: cache attribute */
		pg_m:1,			/* HW: dirty bit */
		pg_v:1,			/* HW: valid bit */
		pg_g:1;			/* HW: ignore asid bit */
#endif
#if BYTE_ORDER == LITTLE_ENDIAN
unsigned int 	pg_g:1,			/* HW: ignore asid bit */
		pg_v:1,			/* HW: valid bit */
		pg_m:1,			/* HW: dirty bit */
		pg_attr:3,		/* HW: cache attribute */
		pg_pfnum:24,		/* HW: core page frame number or 0 */
		pg_prot:2;		/* SW: access control */
#endif
};
#endif
#endif /* _LOCORE */

#define	MIPS3_PG_WIRED	0x80000000	/* SW */
#define	MIPS3_PG_RO	0x40000000	/* SW */

#if PGSHIFT == 14
#define	MIPS3_PG_SVPN	(~0UL << 14)	/* Software page no mask */
#define	MIPS3_PG_HVPN	(~0UL << 15)	/* Hardware page no mask */
#define	MIPS3_PG_ODDPG	(MIPS3_PG_SVPN ^ MIPS3_PG_HVPN)
#elif PGSHIFT == 13
#ifdef MIPS3_4100
#define	8KB page size is not supported on the MIPS3_4100
#endif
#define	MIPS3_PG_SVPN	(~0UL << 13)	/* Software page no mask */
#define	MIPS3_PG_HVPN	(~0UL << 13)	/* Hardware page no mask */
#define	MIPS3_PG_NEXT	(1 << (12 - MIPS3_DEFAULT_PG_SHIFT))
#elif PGSHIFT == 12
#define	MIPS3_PG_SVPN	(~0UL << 12)	/* Software page no mask */
#define	MIPS3_PG_HVPN	(~0UL << 13)	/* Hardware page no mask */
#define	MIPS3_PG_ODDPG	(MIPS3_PG_SVPN ^ MIPS3_PG_HVPN)
#endif
					/* Odd even pte entry */
#define	MIPS3_PG_ASID	0x000000ff	/* Address space ID */
#define	MIPS3_PG_G	0x00000001	/* Global; ignore ASID if in lo0 & lo1 */
#define	MIPS3_PG_V	0x00000002	/* Valid */
#define	MIPS3_PG_NV	0x00000000
#define	MIPS3_PG_D	0x00000004	/* Dirty */
#define	MIPS3_PG_ATTR	0x0000003f

#define	MIPS3_CCA_TO_PG(cca)	((cca) << 3)
#define	MIPS3_PG_TO_CCA(cca)	(((cca) >> 3) & 7)

#define	MIPS3_XPHYS_UNCACHED	MIPS_PHYS_TO_XKPHYS(2, 0)
#define	MIPS3_XPHYS_ACC		MIPS_PHYS_TO_XKPHYS(mips_options.mips3_cca_devmem, 0)

#define	MIPS3_PG_UNCACHED	MIPS3_CCA_TO_PG(2)
#define	MIPS3_PG_WT		MIPS3_CCA_TO_PG(5)
#define	MIPS3_PG_ACC		MIPS3_CCA_TO_PG(mips_options.mips3_cca_devmem)
#ifdef HPCMIPS_L1CACHE_DISABLE		/* MIPS3_L1CACHE_DISABLE */
#define	MIPS3_DEFAULT_XKPHYS_CACHED	MIPS3_DEFAULT_XKPHYS_UNCACHED
#define	MIPS3_PG_CACHED		MIPS3_PG_UNCACHED	/* XXX: brain damaged!!! */
#else /* HPCMIPS_L1CACHE_DISABLE */
#define	MIPS3_DEFAULT_XKPHYS_CACHED	MIPS_PHYS_TO_XKPHYS(3, 0)
#define	MIPS3_PG_CACHED		mips_options.mips3_pg_cached
#define	MIPS3_DEFAULT_PG_CACHED	MIPS3_CCA_TO_PG(3)
#endif /* ! HPCMIPS_L1CACHE_DISABLE */
#define	MIPS3_PG_CACHEMODE	MIPS3_CCA_TO_PG(7)

/* Write protected */
#define	MIPS3_PG_ROPAGE	(MIPS3_PG_V | MIPS3_PG_RO | MIPS3_PG_CACHED)

/* Not wr-prot not clean */
#define	MIPS3_PG_RWPAGE	(MIPS3_PG_V | MIPS3_PG_D | MIPS3_PG_CACHED)

/* Not wr-prot not clean not cached */
#define	MIPS3_PG_RWNCPAGE	(MIPS3_PG_V | MIPS3_PG_D | MIPS3_PG_UNCACHED)

/* Not wr-prot not clean not cached, accel */
#define	MIPS3_PG_RWAPAGE	(MIPS3_PG_V | MIPS3_PG_D | MIPS3_PG_ACC)

/* Not wr-prot but clean */
#define	MIPS3_PG_CWPAGE	(MIPS3_PG_V | MIPS3_PG_CACHED)

/* Not wr-prot but clean not cached*/
#define	MIPS3_PG_CWNCPAGE	(MIPS3_PG_V | MIPS3_PG_UNCACHED)

/* Not wr-prot but clean not cached, accel*/
#define	MIPS3_PG_CWAPAGE	(MIPS3_PG_V | MIPS3_PG_ACC)

#define	MIPS3_PG_IOPAGE(cca) \
	(MIPS3_PG_G | MIPS3_PG_V | MIPS3_PG_D | MIPS3_CCA_TO_PG(cca))
#define	MIPS3_PG_FRAME	0x3fffffc0

#define	MIPS3_DEFAULT_PG_SHIFT	6
#define	MIPS3_4100_PG_SHIFT	4

/* NEC Vr4100 CPUs have different PFN layout to support 1kbytes/page */
#if defined(MIPS3_4100)
#define	MIPS3_PG_SHIFT	mips_options.mips3_pg_shift
#else
#define	MIPS3_PG_SHIFT	MIPS3_DEFAULT_PG_SHIFT
#endif

/* pte accessor macros */

#define	mips3_pfn_is_ext(x) ((x) & 0x3c000000)
#define	mips3_paddr_to_tlbpfn(x) \
    (((paddr_t)(x) >> MIPS3_PG_SHIFT) & MIPS3_PG_FRAME)
#define	mips3_tlbpfn_to_paddr(x) \
    ((paddr_t)((x) & MIPS3_PG_FRAME) << MIPS3_PG_SHIFT)
#define	mips3_vad_to_vpn(x) ((vaddr_t)(x) & MIPS3_PG_SVPN)
#define	mips3_vpn_to_vad(x) ((x) & MIPS3_PG_SVPN)

#define	MIPS3_PTE_TO_PADDR(pte) (mips3_tlbpfn_to_paddr(pte))
#define	MIPS3_PAGE_IS_RDONLY(pte,va) \
    (pmap_is_page_ro_p(pmap_kernel(), mips_trunc_page(va), (pte)))


#define	MIPS3_PG_SIZE_4K	0x00000000
#define	MIPS3_PG_SIZE_16K	0x00006000
#define	MIPS3_PG_SIZE_64K	0x0001e000
#define	MIPS3_PG_SIZE_256K	0x0007e000
#define	MIPS3_PG_SIZE_1M	0x001fe000
#define	MIPS3_PG_SIZE_4M	0x007fe000
#define	MIPS3_PG_SIZE_16M	0x01ffe000
#define	MIPS3_PG_SIZE_64M	0x07ffe000
#define	MIPS3_PG_SIZE_256M	0x1fffe000

#ifdef _KERNEL
#define	MIPS3_PG_SIZE_MASK_TO_SIZE(pg_mask)	\
    ((((pg_mask) | 0x00001fff) + 1) / 2)

#define	MIPS3_PG_SIZE_TO_MASK(pg_size)		\
    ((((pg_size) << (((pg_size) & 0x2aaaa) == 0)) - 1) & ~0x00001fff)

CTASSERT(MIPS3_PG_SIZE_TO_MASK(4096) == MIPS3_PG_SIZE_4K);
CTASSERT(MIPS3_PG_SIZE_TO_MASK(8192) == MIPS3_PG_SIZE_4K);
#endif

/* NEC Vr41xx uses different pagemask values. */
#define	MIPS4100_PG_SIZE_1K	0x00000000
#define	MIPS4100_PG_SIZE_4K	0x00001800
#define	MIPS4100_PG_SIZE_16K	0x00007800
#define	MIPS4100_PG_SIZE_64K	0x0001f800
#define	MIPS4100_PG_SIZE_256K	0x0007f800

#define	MIPS4100_PG_SIZE_MASK_TO_SIZE(pg_mask)	\
    ((((pg_mask) | 0x000007ff) + 1) / 2)

#define	MIPS4100_PG_SIZE_TO_MASK(pg_size)		\
    ((((pg_size) * 2) - 1) & ~0x000007ff)

#endif /* !_MIPS_MIPS3_PTE_H_ */