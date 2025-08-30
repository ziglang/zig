/* $NetBSD: pte.h,v 1.14 2022/08/19 08:17:32 ryo Exp $ */

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

#ifndef _AARCH64_PTE_H_
#define _AARCH64_PTE_H_

#ifdef __aarch64__

#ifndef _LOCORE
typedef uint64_t pd_entry_t;	/* L0(512G) / L1(1G) / L2(2M) table entry */

#ifndef __BSD_PTENTRY_T__
#define __BSD_PTENTRY_T__
typedef uint64_t pt_entry_t;	/* L3(4k) table entry */
#define PRIxPTE         PRIx64
#endif /* __BSD_PTENTRY_T__ */

#endif /* _LOCORE */

/*
 * translation table, block, and page descriptors
 */
#define LX_TBL_NSTABLE		__BIT(63)	/* inherited next level */
#define LX_TBL_APTABLE		__BITS(62,61)	/* inherited next level */
#define  LX_TBL_APTABLE_NOEFFECT	__SHIFTIN(0,LX_TBL_APTABLE)
#define  LX_TBL_APTABLE_EL0_NOACCESS	__SHIFTIN(1,LX_TBL_APTABLE)
#define  LX_TBL_APTABLE_RO		__SHIFTIN(2,LX_TBL_APTABLE)
#define  LX_TBL_APTABLE_RO_EL0_NOREAD	__SHIFTIN(3,LX_TBL_APTABLE)
#define LX_TBL_UXNTABLE		__BIT(60)	/* inherited next level */
#define LX_TBL_PXNTABLE		__BIT(59)	/* inherited next level */
#define LX_BLKPAG_OS		__BITS(58, 55)
#define  LX_BLKPAG_OS_0		__SHIFTIN(1,LX_BLKPAG_OS)
#define  LX_BLKPAG_OS_1		__SHIFTIN(2,LX_BLKPAG_OS)
#define  LX_BLKPAG_OS_2		__SHIFTIN(4,LX_BLKPAG_OS)
#define  LX_BLKPAG_OS_3		__SHIFTIN(8,LX_BLKPAG_OS)
#define LX_BLKPAG_UXN		__BIT(54)	/* Unprivileged Execute Never */
#define LX_BLKPAG_PXN		__BIT(53)	/* Privileged Execute Never */
#define LX_BLKPAG_CONTIG	__BIT(52)	/* Hint of TLB cache */
#define LX_BLKPAG_DBM		__BIT(51)	/* Dirty Bit Modifier (V8.1) */
#define LX_BLKPAG_GP		__BIT(50)	/* Guarded Page (V8.5) */
#define LX_TBL_PA		__BITS(47, 12)
#define LX_BLKPAG_OA		__BITS(47, 12)
#define LX_BLKPAG_NG		__BIT(11)	/* Not Global */
#define LX_BLKPAG_AF		__BIT(10)	/* Access Flag */
#define LX_BLKPAG_SH		__BITS(9,8)	/* Shareability */
#define  LX_BLKPAG_SH_NS	__SHIFTIN(0,LX_BLKPAG_SH) /* Non Shareable */
#define  LX_BLKPAG_SH_OS	__SHIFTIN(2,LX_BLKPAG_SH) /* Outer Shareable */
#define  LX_BLKPAG_SH_IS	__SHIFTIN(3,LX_BLKPAG_SH) /* Inner Shareable */
#define LX_BLKPAG_AP		__BIT(7)
#define  LX_BLKPAG_AP_RW	__SHIFTIN(0,LX_BLKPAG_AP) /* RW */
#define  LX_BLKPAG_AP_RO	__SHIFTIN(1,LX_BLKPAG_AP) /* RO */
#define LX_BLKPAG_APUSER	__BIT(6)
#define LX_BLKPAG_NS		__BIT(5)
#define LX_BLKPAG_ATTR_INDX	__BITS(4,2)	/* refer MAIR_EL1 attr<n> */
#define  LX_BLKPAG_ATTR_INDX_0	__SHIFTIN(0,LX_BLKPAG_ATTR_INDX)
#define  LX_BLKPAG_ATTR_INDX_1	__SHIFTIN(1,LX_BLKPAG_ATTR_INDX)
#define  LX_BLKPAG_ATTR_INDX_2	__SHIFTIN(2,LX_BLKPAG_ATTR_INDX)
#define  LX_BLKPAG_ATTR_INDX_3	__SHIFTIN(3,LX_BLKPAG_ATTR_INDX)
#define LX_TYPE			__BIT(1)
#define  LX_TYPE_BLK		__SHIFTIN(0, LX_TYPE)
#define  LX_TYPE_TBL		__SHIFTIN(1, LX_TYPE)
#define  L3_TYPE_PAG		__SHIFTIN(1, LX_TYPE)
#define LX_VALID		__BIT(0)

#define L1_BLK_OA		__BITS(47, 30)	/* 1GB */
#define L2_BLK_OA		__BITS(47, 21)	/* 2MB */
#define L3_PAG_OA		__BITS(47, 12)	/* 4KB */
#define AARCH64_MAX_PA		__BIT(48)


/* L0 table, 512GB/entry * 512 */
#define L0_SHIFT		39
#define L0_ADDR_BITS		__BITS(47,39)
#define L0_SIZE			(1UL << L0_SHIFT)
#define L0_OFFSET		(L0_SIZE - 1UL)
#define L0_FRAME		(~L0_OFFSET)
/*      L0_BLOCK		Level 0 doesn't support block translation */
#define L0_TABLE		(LX_TYPE_TBL | LX_VALID)

/* L1 table, 1GB/entry * 512 */
#define L1_SHIFT		30
#define L1_ADDR_BITS		__BITS(38,30)
#define L1_SIZE			(1UL << L1_SHIFT)
#define L1_OFFSET		(L1_SIZE - 1UL)
#define L1_FRAME		(~L1_OFFSET)
#define L1_BLOCK		(LX_TYPE_BLK | LX_VALID)
#define L1_TABLE		(LX_TYPE_TBL | LX_VALID)

/* L2 table, 2MB/entry * 512 */
#define L2_SHIFT		21
#define L2_ADDR_BITS		__BITS(29,21)
#define L2_SIZE			(1UL << L2_SHIFT)
#define L2_OFFSET		(L2_SIZE - 1UL)
#define L2_FRAME		(~L2_OFFSET)
#define L2_BLOCK		(LX_TYPE_BLK | LX_VALID)
#define L2_TABLE		(LX_TYPE_TBL | LX_VALID)
#define L2_BLOCK_MASK		__BITS(47,21)

/* L3 table, 4KB/entry * 512 */
#define L3_SHIFT		12
#define L3_ADDR_BITS		__BITS(20,12)
#define L3_SIZE			(1UL << L3_SHIFT)
#define L3_OFFSET		(L3_SIZE - 1UL)
#define L3_FRAME		(~L3_OFFSET)
#define L3_PAGE			(L3_TYPE_PAG | LX_VALID)

#define Ln_ENTRIES_SHIFT	9
#define Ln_ENTRIES		(1 << Ln_ENTRIES_SHIFT)
#define Ln_TABLE_SIZE		(8 << Ln_ENTRIES_SHIFT)

#elif defined(__arm__)

#include <arm/pte.h>

#endif /* __aarch64__/__arm__ */

#endif /* _AARCH64_PTE_H_ */