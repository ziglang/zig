/*-
 * Copyright (c) 2014 Andrew Turner
 * Copyright (c) 2014-2015 The FreeBSD Foundation
 * All rights reserved.
 *
 * This software was developed by Andrew Turner under
 * sponsorship from the FreeBSD Foundation.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifdef __arm__
#include <arm/pte.h>
#else /* !__arm__ */

#ifndef _MACHINE_PTE_H_
#define	_MACHINE_PTE_H_

#ifndef LOCORE
typedef	uint64_t	pd_entry_t;		/* page directory entry */
typedef	uint64_t	pt_entry_t;		/* page table entry */
#endif

/* Table attributes */
#define	TATTR_MASK		UINT64_C(0xfff8000000000000)
#define	TATTR_AP_TABLE_MASK	(3UL << 61)
#define	TATTR_AP_TABLE_RO	(2UL << 61)
#define	TATTR_AP_TABLE_NO_EL0	(1UL << 61)
#define	TATTR_UXN_TABLE		(1UL << 60)
#define	TATTR_PXN_TABLE		(1UL << 59)
/* Bits 58:51 are ignored */

/* Block and Page attributes */
#define	ATTR_MASK_H		UINT64_C(0xfffc000000000000)
#define	ATTR_MASK_L		UINT64_C(0x0000000000000fff)
#define	ATTR_MASK		(ATTR_MASK_H | ATTR_MASK_L)

#define BASE_MASK		~ATTR_MASK
#define BASE_ADDR(x)		((x) & BASE_MASK)

#define PTE_TO_PHYS(pte)	BASE_ADDR(pte)
/* Convert a phys addr to the output address field of a PTE */
#define PHYS_TO_PTE(pa)		(pa)

/* Bits 58:55 are reserved for software */
#define	ATTR_SW_UNUSED1		(1UL << 58)
#define	ATTR_SW_NO_PROMOTE	(1UL << 57)
#define	ATTR_SW_MANAGED		(1UL << 56)
#define	ATTR_SW_WIRED		(1UL << 55)

#define	ATTR_S1_UXN		(1UL << 54)
#define	ATTR_S1_PXN		(1UL << 53)
#define	ATTR_S1_XN		(ATTR_S1_PXN | ATTR_S1_UXN)

#define	ATTR_S2_XN(x)		((x) << 53)
#define	 ATTR_S2_XN_MASK	ATTR_S2_XN(3UL)
#define	 ATTR_S2_XN_NONE	0UL	/* Allow execution at EL0 & EL1 */
#define	 ATTR_S2_XN_EL1		1UL	/* Allow execution at EL0 */
#define	 ATTR_S2_XN_ALL		2UL	/* No execution */
#define	 ATTR_S2_XN_EL0		3UL	/* Allow execution at EL1 */

#define	ATTR_CONTIGUOUS		(1UL << 52)
#define	ATTR_DBM		(1UL << 51)
#define	ATTR_S1_nG		(1 << 11)
#define	ATTR_AF			(1 << 10)
#define	ATTR_SH(x)		((x) << 8)
#define	 ATTR_SH_MASK		ATTR_SH(3)
#define	 ATTR_SH_NS		0		/* Non-shareable */
#define	 ATTR_SH_OS		2		/* Outer-shareable */
#define	 ATTR_SH_IS		3		/* Inner-shareable */

#define	ATTR_S1_AP_RW_BIT	(1 << 7)
#define	ATTR_S1_AP(x)		((x) << 6)
#define	 ATTR_S1_AP_MASK	ATTR_S1_AP(3)
#define	 ATTR_S1_AP_RW		(0 << 1)
#define	 ATTR_S1_AP_RO		(1 << 1)
#define	 ATTR_S1_AP_USER	(1 << 0)
#define	ATTR_S1_NS		(1 << 5)
#define	ATTR_S1_IDX(x)		((x) << 2)
#define	ATTR_S1_IDX_MASK	(7 << 2)

#define	ATTR_S2_S2AP(x)		((x) << 6)
#define	 ATTR_S2_S2AP_MASK	3
#define	 ATTR_S2_S2AP_READ	1
#define	 ATTR_S2_S2AP_WRITE	2

#define	ATTR_S2_MEMATTR(x)		((x) << 2)
#define	 ATTR_S2_MEMATTR_MASK		ATTR_S2_MEMATTR(0xf)
#define	 ATTR_S2_MEMATTR_DEVICE_nGnRnE	0x0
#define	 ATTR_S2_MEMATTR_NC		0xf
#define	 ATTR_S2_MEMATTR_WT		0xa
#define	 ATTR_S2_MEMATTR_WB		0xf

#define	ATTR_DEFAULT	(ATTR_AF | ATTR_SH(ATTR_SH_IS))

#define	ATTR_DESCR_MASK		3
#define	ATTR_DESCR_VALID	1
#define	ATTR_DESCR_TYPE_MASK	2
#define	ATTR_DESCR_TYPE_TABLE	2
#define	ATTR_DESCR_TYPE_PAGE	2
#define	ATTR_DESCR_TYPE_BLOCK	0

#if PAGE_SIZE == PAGE_SIZE_4K
#define	L0_SHIFT	39
#define	L1_SHIFT	30
#define	L2_SHIFT	21
#define	L3_SHIFT	12
#elif PAGE_SIZE == PAGE_SIZE_16K
#define	L0_SHIFT	47
#define	L1_SHIFT	36
#define	L2_SHIFT	25
#define	L3_SHIFT	14
#else
#error Unsupported page size
#endif

/* Level 0 table, 512GiB/128TiB per entry */
#define	L0_SIZE		(UINT64_C(1) << L0_SHIFT)
#define	L0_OFFSET	(L0_SIZE - 1ul)
#define	L0_INVAL	0x0 /* An invalid address */
	/* 0x1 Level 0 doesn't support block translation */
	/* 0x2 also marks an invalid address */
#define	L0_TABLE	0x3 /* A next-level table */

/* Level 1 table, 1GiB/64GiB per entry */
#define	L1_SIZE 	(UINT64_C(1) << L1_SHIFT)
#define	L1_OFFSET 	(L1_SIZE - 1)
#define	L1_INVAL	L0_INVAL
#define	L1_BLOCK	0x1
#define	L1_TABLE	L0_TABLE

/* Level 2 table, 2MiB/32MiB per entry */
#define	L2_SIZE 	(UINT64_C(1) << L2_SHIFT)
#define	L2_OFFSET 	(L2_SIZE - 1)
#define	L2_INVAL	L1_INVAL
#define	L2_BLOCK	0x1
#define	L2_TABLE	L1_TABLE

/* Level 3 table, 4KiB/16KiB per entry */
#define	L3_SIZE 	(1 << L3_SHIFT)
#define	L3_OFFSET 	(L3_SIZE - 1)
#define	L3_INVAL	0x0
	/* 0x1 is reserved */
	/* 0x2 also marks an invalid address */
#define	L3_PAGE		0x3

/*
 * A substantial portion of this is to make sure that we can cope with 4K
 * framebuffers in early boot, assuming a common 4K resolution @ 32-bit depth.
 */
#define	PMAP_MAPDEV_EARLY_SIZE	(L2_SIZE * 20)

#if PAGE_SIZE == PAGE_SIZE_4K
#define	L0_ENTRIES_SHIFT 9
#define	Ln_ENTRIES_SHIFT 9
#elif PAGE_SIZE == PAGE_SIZE_16K
#define	L0_ENTRIES_SHIFT 1
#define	Ln_ENTRIES_SHIFT 11
#else
#error Unsupported page size
#endif

#define	L0_ENTRIES	(1 << L0_ENTRIES_SHIFT)
#define	L0_ADDR_MASK	(L0_ENTRIES - 1)

#define	Ln_ENTRIES	(1 << Ln_ENTRIES_SHIFT)
#define	Ln_ADDR_MASK	(Ln_ENTRIES - 1)
#define	Ln_TABLE_MASK	((1 << 12) - 1)

#define	pmap_l0_index(va)	(((va) >> L0_SHIFT) & L0_ADDR_MASK)
#define	pmap_l1_index(va)	(((va) >> L1_SHIFT) & Ln_ADDR_MASK)
#define	pmap_l2_index(va)	(((va) >> L2_SHIFT) & Ln_ADDR_MASK)
#define	pmap_l3_index(va)	(((va) >> L3_SHIFT) & Ln_ADDR_MASK)

#endif /* !_MACHINE_PTE_H_ */

/* End of pte.h */

#endif /* !__arm__ */