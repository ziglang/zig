/*	$NetBSD: cpuregs.h,v 1.116 2021/11/16 06:11:52 simonb Exp $	*/

/*
 * Copyright (c) 2009 Miodrag Vallat.
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

/*
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Ralph Campbell and Rick Macklem.
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
 *	@(#)machConst.h 8.1 (Berkeley) 6/10/93
 *
 * machConst.h --
 *
 *	Machine dependent constants.
 *
 *	Copyright (C) 1989 Digital Equipment Corporation.
 *	Permission to use, copy, modify, and distribute this software and
 *	its documentation for any purpose and without fee is hereby granted,
 *	provided that the above copyright notice appears in all copies.
 *	Digital Equipment Corporation makes no representations about the
 *	suitability of this software for any purpose.  It is provided "as is"
 *	without express or implied warranty.
 *
 * from: Header: /sprite/src/kernel/mach/ds3100.md/RCS/machConst.h,
 *	v 9.2 89/10/21 15:55:22 jhh Exp	 SPRITE (DECWRL)
 * from: Header: /sprite/src/kernel/mach/ds3100.md/RCS/machAddrs.h,
 *	v 1.2 89/08/15 18:28:21 rab Exp	 SPRITE (DECWRL)
 * from: Header: /sprite/src/kernel/vm/ds3100.md/RCS/vmPmaxConst.h,
 *	v 9.1 89/09/18 17:33:00 shirriff Exp  SPRITE (DECWRL)
 */

#ifndef _MIPS_CPUREGS_H_
#define	_MIPS_CPUREGS_H_

#include <sys/cdefs.h>		/* For __CONCAT() */

#if defined(_KERNEL_OPT)
#include "opt_cputype.h"
#endif

/*
 * Address space.
 * 32-bit mips CPUS partition their 32-bit address space into four segments:
 *
 * kuseg   0x00000000 - 0x7fffffff  User virtual mem,  mapped
 * kseg0   0x80000000 - 0x9fffffff  Physical memory, cached, unmapped
 * kseg1   0xa0000000 - 0xbfffffff  Physical memory, uncached, unmapped
 * kseg2   0xc0000000 - 0xffffffff  kernel-virtual,  mapped
 *
 * mips1 physical memory is limited to 512Mbytes, which is
 * doubly mapped in kseg0 (cached) and kseg1 (uncached.)
 * Caching of mapped addresses is controlled by bits in the TLB entry.
 */

#ifdef _LP64
#define	MIPS_XUSEG_START		(0L << 62)
#define	MIPS_XUSEG_P(x)			(((uint64_t)(x) >> 62) == 0)
#define	MIPS_USEG_P(x)			((uintptr_t)(x) < 0x80000000L)
#define	MIPS_XSSEG_START		(1L << 62)
#define	MIPS_XSSEG_P(x)			(((uint64_t)(x) >> 62) == 1)
#endif

/*
 * MIPS addresses are signed and we defining as negative so that
 * in LP64 kern they get sign-extended correctly.
 */
#ifndef _LOCORE
#define	MIPS_KSEG0_START		(-0x7fffffffL-1) /* 0x80000000 */
#define	MIPS_KSEG1_START		-0x60000000L	/* 0xa0000000 */
#define	MIPS_KSEG2_START		-0x40000000L	/* 0xc0000000 */
#define	MIPS_MAX_MEM_ADDR		-0x42000000L	/* 0xbe000000 */
#define	MIPS_RESERVED_ADDR		-0x40380000L	/* 0xbfc80000 */
#endif

#define	MIPS_PHYS_MASK			0x1fffffff

#define	MIPS_KSEG0_TO_PHYS(x)	((uintptr_t)(x) & MIPS_PHYS_MASK)
#define	MIPS_PHYS_TO_KSEG0(x)	((intptr_t)((x) + MIPS_KSEG0_START))
#define	MIPS_KSEG1_TO_PHYS(x)	((uintptr_t)(x) & MIPS_PHYS_MASK)
#define	MIPS_PHYS_TO_KSEG1(x)	((intptr_t)(x) | (intptr_t)MIPS_KSEG1_START)

#define	MIPS_KSEG0_P(x)		(((intptr_t)(x) & ~MIPS_PHYS_MASK) == MIPS_KSEG0_START)
#define	MIPS_KSEG1_P(x)		(((intptr_t)(x) & ~MIPS_PHYS_MASK) == MIPS_KSEG1_START)
#define	MIPS_KSEG2_P(x)		((uintptr_t)MIPS_KSEG2_START <= (uintptr_t)(x))

/* Map virtual address to index in mips3 r4k virtually-indexed cache */
#define	MIPS3_VA_TO_CINDEX(x) \
		(((intptr_t)(x) & 0xffffff) | MIPS_KSEG0_START)

#ifndef _LOCORE
#define	MIPS_XSEG_MASK		(0x3fffffffffffffffLL)
#define	MIPS_XKSEG_START	(0x3ULL << 62)
#define	MIPS_XKSEG_P(x)		(((uint64_t)(x) >> 62) == 3)

#define	MIPS_XKPHYS_START	(0x2ULL << 62)
#define	MIPS_PHYS_TO_XKPHYS_UNCACHED(x) \
	(MIPS_XKPHYS_START | ((uint64_t)(CCA_UNCACHED) << 59) | (x))
#define	MIPS_PHYS_TO_XKPHYS_ACC(x) \
	(MIPS_XKPHYS_START | ((uint64_t)(mips_options.mips3_cca_devmem) << 59) | (x))
#define	MIPS_PHYS_TO_XKPHYS_CACHED(x) \
	(mips_options.mips3_xkphys_cached | (x))
#define	MIPS_PHYS_TO_XKPHYS(cca,x) \
	(MIPS_XKPHYS_START | ((uint64_t)(cca) << 59) | (x))
#define	MIPS_XKPHYS_TO_PHYS(x)	((uint64_t)(x) & 0x07ffffffffffffffLL)
#define	MIPS_XKPHYS_TO_CCA(x)	(((uint64_t)(x) >> 59) & 7)
#define	MIPS_XKPHYS_P(x)	(((uint64_t)(x) >> 62) == 2)
#endif	/* _LOCORE */

#define	CCA_UNCACHED		2
#define	CCA_CACHEABLE		3	/* cacheable non-coherent */
#define	CCA_SB_CACHEABLE_COHERENT 5	/* cacheable coherent (SiByte ext) */
#define	CCA_ACCEL		7	/* non-cached, write combining */

/* CPU dependent mtc0 hazard hook */
#if (MIPS32R2 + MIPS64R2) > 0
# if (MIPS1 + MIPS3 + MIPS32 + MIPS64) == 0
#  define COP0_SYNC		sll $0,$0,3	/* EHB */
#  define JR_HB_RA		.set push; .set mips32r2; jr.hb ra; nop; .set pop
# else
#  define COP0_SYNC		sll $0,$0,1; sll $0,$0,1; sll $0,$0,3
#  define JR_HB_RA		sll $0,$0,1; sll $0,$0,1; jr ra; sll $0,$0,3
# endif
#elif (MIPS32 + MIPS64) > 0
# define COP0_SYNC		sll $0,$0,1; sll $0,$0,1; sll $0,$0,1
# define JR_HB_RA		sll $0,$0,1; sll $0,$0,1; jr ra; sll $0,$0,1
#elif MIPS3 > 0
# define COP0_SYNC		nop; nop; nop
# define JR_HB_RA		nop; nop; jr ra; nop
#else
# define COP0_SYNC		nop
# define JR_HB_RA		jr ra; nop
#endif
#define	COP0_HAZARD_FPUENABLE	nop; nop; nop; nop;

/*
 * The bits in the cause register.
 *
 * Bits common to r3000 and r4000:
 *
 *	MIPS_CR_BR_DELAY	Exception happened in branch delay slot.
 *	MIPS_CR_COP_ERR		Coprocessor error.
 *	MIPS_CR_IP		Interrupt pending bits defined below.
 *				(same meaning as in CAUSE register).
 *	MIPS_CR_EXC_CODE	The exception type (see exception codes below).
 *
 * Differences:
 *  r3k has 4 bits of exception type, r4k has 5 bits.
 */
#define	MIPS_CR_BR_DELAY	0x80000000
#define	MIPS_CR_COP_ERR		0x30000000
#define	 MIPS_CR_COP_ERR_CU1	  1
#define	 MIPS_CR_COP_ERR_CU2	  2
#define	 MIPS_CR_COP_ERR_CU3	  3
#define	MIPS1_CR_EXC_CODE	0x0000003C	/* four bits */
#define	MIPS3_CR_EXC_CODE	0x0000007C	/* five bits */
#define	MIPS_CR_IP		0x0000FF00
#define	MIPS_CR_EXC_CODE_SHIFT	2

/*
 * The bits in the status register.  All bits are active when set to 1.
 *
 *	R3000 status register fields:
 *	MIPS_SR_COP_USABILITY	Control the usability of the four coprocessors.
 *	MIPS_SR_TS		TLB shutdown.
 *
 *	MIPS_SR_INT_IE		Master (current) interrupt enable bit.
 *
 * Differences:
 *	r3k has cache control is via frobbing SR register bits, whereas the
 *	r4k cache control is via explicit instructions.
 *	r3k has a 3-entry stack of kernel/user bits, whereas the
 *	r4k has kernel/supervisor/user.
 */
#define	MIPS_SR_COP_USABILITY	0xf0000000
#define	MIPS_SR_COP_0_BIT	0x10000000
#define	MIPS_SR_COP_1_BIT	0x20000000
#define	MIPS_SR_COP_2_BIT	0x40000000

	/* r4k and r3k differences, see below */

#define	MIPS_SR_MX		0x01000000	/* MIPS64 */
#define	MIPS_SR_PX		0x00800000	/* MIPS64 */
#define	MIPS_SR_BEV		0x00400000	/* Use boot exception vector */
#define	MIPS_SR_TS		0x00200000

	/* r4k and r3k differences, see below */

#define	MIPS_SR_INT_IE		0x00000001
/*#define MIPS_SR_MBZ		0x0f8000c0*/	/* Never used, true for r3k */
/*#define MIPS_SR_INT_MASK	0x0000ff00*/


/*
 * The R2000/R3000-specific status register bit definitions.
 * all bits are active when set to 1.
 *
 *	MIPS_SR_PARITY_ERR	Parity error.
 *	MIPS_SR_CACHE_MISS	Most recent D-cache load resulted in a miss.
 *	MIPS_SR_PARITY_ZERO	Zero replaces outgoing parity bits.
 *	MIPS_SR_SWAP_CACHES	Swap I-cache and D-cache.
 *	MIPS_SR_ISOL_CACHES	Isolate D-cache from main memory.
 *				Interrupt enable bits defined below.
 *	MIPS_SR_KU_OLD		Old kernel/user mode bit. 1 => user mode.
 *	MIPS_SR_INT_ENA_OLD	Old interrupt enable bit.
 *	MIPS_SR_KU_PREV		Previous kernel/user mode bit. 1 => user mode.
 *	MIPS_SR_INT_ENA_PREV	Previous interrupt enable bit.
 *	MIPS_SR_KU_CUR		Current kernel/user mode bit. 1 => user mode.
 */

#define	MIPS1_PARITY_ERR	0x00100000
#define	MIPS1_CACHE_MISS	0x00080000
#define	MIPS1_PARITY_ZERO	0x00040000
#define	MIPS1_SWAP_CACHES	0x00020000
#define	MIPS1_ISOL_CACHES	0x00010000

#define	MIPS1_SR_KU_OLD		0x00000020	/* 2nd stacked KU/IE*/
#define	MIPS1_SR_INT_ENA_OLD	0x00000010	/* 2nd stacked KU/IE*/
#define	MIPS1_SR_KU_PREV	0x00000008	/* 1st stacked KU/IE*/
#define	MIPS1_SR_INT_ENA_PREV	0x00000004	/* 1st stacked KU/IE*/
#define	MIPS1_SR_KU_CUR		0x00000002	/* current KU */

/* backwards compatibility */
#define	MIPS_SR_PARITY_ERR	MIPS1_PARITY_ERR
#define	MIPS_SR_CACHE_MISS	MIPS1_CACHE_MISS
#define	MIPS_SR_PARITY_ZERO	MIPS1_PARITY_ZERO
#define	MIPS_SR_SWAP_CACHES	MIPS1_SWAP_CACHES
#define	MIPS_SR_ISOL_CACHES	MIPS1_ISOL_CACHES

#define	MIPS_SR_KU_OLD		MIPS1_SR_KU_OLD
#define	MIPS_SR_INT_ENA_OLD	MIPS1_SR_INT_ENA_OLD
#define	MIPS_SR_KU_PREV		MIPS1_SR_KU_PREV
#define	MIPS_SR_KU_CUR		MIPS1_SR_KU_CUR
#define	MIPS_SR_INT_ENA_PREV	MIPS1_SR_INT_ENA_PREV

/*
 * R4000 status register bit definitions,
 * where different from r2000/r3000.
 */
#define	MIPS3_SR_XX		0x80000000
#define	MIPS3_SR_RP		0x08000000
#define	MIPS3_SR_FR		0x04000000
#define	MIPS3_SR_RE		0x02000000

#define	MIPS3_SR_DIAG_DL	0x01000000		/* QED 52xx */
#define	MIPS3_SR_DIAG_IL	0x00800000		/* QED 52xx */
#define	MIPS3_SR_PX		0x00800000		/* MIPS64 */
#define	MIPS3_SR_SR		0x00100000
#define	MIPS3_SR_NMI		0x00080000		/* MIPS32/64 */
#define	MIPS3_SR_DIAG_CH	0x00040000
#define	MIPS3_SR_DIAG_CE	0x00020000
#define	MIPS3_SR_DIAG_PE	0x00010000
#define	MIPS3_SR_KX		0x00000080
#define	MIPS3_SR_SX		0x00000040
#define	MIPS3_SR_UX		0x00000020
#define	MIPS3_SR_KSU_MASK	0x00000018
#define	MIPS3_SR_KSU_USER	0x00000010
#define	MIPS3_SR_KSU_SUPER	0x00000008
#define	MIPS3_SR_KSU_KERNEL	0x00000000
#define	MIPS3_SR_ERL		0x00000004
#define	MIPS3_SR_EXL		0x00000002

#define	MIPS_SR_SOFT_RESET	MIPS3_SR_SOFT_RESET
#define	MIPS_SR_DIAG_CH		MIPS3_SR_DIAG_CH
#define	MIPS_SR_DIAG_CE		MIPS3_SR_DIAG_CE
#define	MIPS_SR_DIAG_PE		MIPS3_SR_DIAG_PE
#define	MIPS_SR_KX		MIPS3_SR_KX
#define	MIPS_SR_SX		MIPS3_SR_SX
#define	MIPS_SR_UX		MIPS3_SR_UX

#define	MIPS_SR_KSU_MASK	MIPS3_SR_KSU_MASK
#define	MIPS_SR_KSU_USER	MIPS3_SR_KSU_USER
#define	MIPS_SR_KSU_SUPER	MIPS3_SR_KSU_SUPER
#define	MIPS_SR_KSU_KERNEL	MIPS3_SR_KSU_KERNEL
#define	MIPS_SR_ERL		MIPS3_SR_ERL
#define	MIPS_SR_EXL		MIPS3_SR_EXL


/*
 * The interrupt masks.
 * If a bit in the mask is 1 then the interrupt is enabled (or pending).
 */
#define	MIPS_INT_MASK		0xff00
#define	MIPS_INT_MASK_5		0x8000
#define	MIPS_INT_MASK_4		0x4000
#define	MIPS_INT_MASK_3		0x2000
#define	MIPS_INT_MASK_2		0x1000
#define	MIPS_INT_MASK_1		0x0800
#define	MIPS_INT_MASK_0		0x0400
#define	MIPS_HARD_INT_MASK	0xfc00
#define	MIPS_SOFT_INT_MASK_1	0x0200
#define	MIPS_SOFT_INT_MASK_0	0x0100
#define	MIPS_SOFT_INT_MASK	0x0300
#define	MIPS_INT_MASK_SHIFT	8

/*
 * mips3 CPUs have on-chip timer at INT_MASK_5.  Each platform can
 * choose to enable this interrupt.
 */
#if defined(MIPS3_ENABLE_CLOCK_INTR)
#define	MIPS3_INT_MASK			MIPS_INT_MASK
#define	MIPS3_HARD_INT_MASK		MIPS_HARD_INT_MASK
#else
#define	MIPS3_INT_MASK			(MIPS_INT_MASK &  ~MIPS_INT_MASK_5)
#define	MIPS3_HARD_INT_MASK		(MIPS_HARD_INT_MASK & ~MIPS_INT_MASK_5)
#endif

/*
 * The bits in the context register.
 */
#define	MIPS1_CNTXT_PTE_BASE	0xFFE00000
#define	MIPS1_CNTXT_BAD_VPN	0x001FFFFC

#define	MIPS3_CNTXT_PTE_BASE	0xFF800000
#define	MIPS3_CNTXT_BAD_VPN2	0x007FFFF0

/*
 * The bits in the MIPS3 config register.
 *
 *	bit 0..5: R/W, Bit 6..31: R/O
 */

/* kseg0 coherency algorithm - see MIPS3_TLB_ATTR values */
#define	MIPS3_CONFIG_K0_MASK	0x00000007

/*
 * R/W Update on Store Conditional
 *	0: Store Conditional uses coherency algorithm specified by TLB
 *	1: Store Conditional uses cacheable coherent update on write
 */
#define	MIPS3_CONFIG_CU		0x00000008

#define	MIPS3_CONFIG_DB		0x00000010	/* Primary D-cache line size */
#define	MIPS3_CONFIG_IB		0x00000020	/* Primary I-cache line size */
#define	MIPS3_CONFIG_CACHE_L1_LSIZE(config, bit) \
	(((config) & (bit)) ? 32 : 16)

#define	MIPS3_CONFIG_DC_MASK	0x000001c0	/* Primary D-cache size */
#define	MIPS3_CONFIG_DC_SHIFT	6
#define	MIPS3_CONFIG_IC_MASK	0x00000e00	/* Primary I-cache size */
#define	MIPS3_CONFIG_IC_SHIFT	9
#define	MIPS3_CONFIG_C_DEFBASE	0x1000		/* default base 2^12 */

/* Cache size mode indication: available only on Vr41xx CPUs */
#define	MIPS3_CONFIG_CS		0x00001000
#define	MIPS3_CONFIG_C_4100BASE	0x0400		/* base is 2^10 if CS=1 */
#define	MIPS3_CONFIG_CACHE_SIZE(config, mask, base, shift) \
	((base) << (((config) & (mask)) >> (shift)))

/* External cache enable: Controls L2 for R5000/Rm527x and L3 for Rm7000 */
#define	MIPS3_CONFIG_SE		0x00001000

/* Block ordering: 0: sequential, 1: sub-block */
#define	MIPS3_CONFIG_EB		0x00002000

/* ECC mode - 0: ECC mode, 1: parity mode */
#define	MIPS3_CONFIG_EM		0x00004000

/* BigEndianMem - 0: kernel and memory are little endian, 1: big endian */
#define	MIPS3_CONFIG_BE		0x00008000

/* Dirty Shared coherency state - 0: enabled, 1: disabled */
#define	MIPS3_CONFIG_SM		0x00010000

/* Secondary Cache - 0: present, 1: not present */
#define	MIPS3_CONFIG_SC		0x00020000

/* System Port width - 0: 64-bit, 1: 32-bit (QED RM523x), 2,3: reserved */
#define	MIPS3_CONFIG_EW_MASK	0x000c0000
#define	MIPS3_CONFIG_EW_SHIFT	18

/* Secondary Cache port width - 0: 128-bit data path to S-cache, 1: reserved */
#define	MIPS3_CONFIG_SW		0x00100000

/* Split Secondary Cache Mode - 0: I/D mixed, 1: I/D separated by SCAddr(17) */
#define	MIPS3_CONFIG_SS		0x00200000

/* Secondary Cache line size */
#define	MIPS3_CONFIG_SB_MASK	0x00c00000
#define	MIPS3_CONFIG_SB_SHIFT	22
#define	MIPS3_CONFIG_CACHE_L2_LSIZE(config) \
	(0x10 << (((config) & MIPS3_CONFIG_SB_MASK) >> MIPS3_CONFIG_SB_SHIFT))

/* Write back data rate */
#define	MIPS3_CONFIG_EP_MASK	0x0f000000
#define	MIPS3_CONFIG_EP_SHIFT	24

/* System clock ratio - this value is CPU dependent */
#define	MIPS3_CONFIG_EC_MASK	0x70000000
#define	MIPS3_CONFIG_EC_SHIFT	28

/* Master-Checker Mode - 1: enabled */
#define	MIPS3_CONFIG_CM		0x80000000

/*
 * The bits in the MIPS4 config register.
 */

/* kseg0 coherency algorithm - see MIPS3_TLB_ATTR values */
#define	MIPS4_CONFIG_K0_MASK	MIPS3_CONFIG_K0_MASK
#define	MIPS4_CONFIG_DN_MASK	0x00000018	/* Device number */
#define	MIPS4_CONFIG_CT		0x00000020	/* CohPrcReqTar */
#define	MIPS4_CONFIG_PE		0x00000040	/* PreElmReq */
#define	MIPS4_CONFIG_PM_MASK	0x00000180	/* PreReqMax */
#define	MIPS4_CONFIG_EC_MASK	0x00001e00	/* SysClkDiv */
#define	MIPS4_CONFIG_SB		0x00002000	/* SCBlkSize */
#define	MIPS4_CONFIG_SK		0x00004000	/* SCColEn */
#define	MIPS4_CONFIG_BE		0x00008000	/* MemEnd */
#define	MIPS4_CONFIG_SS_MASK	0x00070000	/* SCSize */
#define	MIPS4_CONFIG_SC_MASK	0x00380000	/* SCClkDiv */
#define	MIPS4_CONFIG_RESERVED	0x03c00000	/* Reserved wired 0 */
#define	MIPS4_CONFIG_DC_MASK	0x1c000000	/* Primary D-Cache size */
#define	MIPS4_CONFIG_IC_MASK	0xe0000000	/* Primary I-Cache size */

#define	MIPS4_CONFIG_DC_SHIFT	26
#define	MIPS4_CONFIG_IC_SHIFT	29

#define	MIPS4_CONFIG_CACHE_SIZE(config, mask, base, shift)		\
	((base) << (((config) & (mask)) >> (shift)))

#define	MIPS4_CONFIG_CACHE_L2_LSIZE(config)				\
	(((config) & MIPS4_CONFIG_SB) ? 128 : 64)

/*
 * Location of exception vectors.
 *
 * Common vectors:  reset and UTLB miss.
 */
#define	MIPS_RESET_EXC_VEC	MIPS_PHYS_TO_KSEG1(0x1FC00000)
#define	MIPS_UTLB_MISS_EXC_VEC	MIPS_PHYS_TO_KSEG0(0)

/*
 * MIPS-1 general exception vector (everything else)
 */
#define	MIPS1_GEN_EXC_VEC	MIPS_PHYS_TO_KSEG0(0x0080)

/*
 * MIPS-III exception vectors
 */
#define	MIPS3_XTLB_MISS_EXC_VEC MIPS_PHYS_TO_KSEG0(0x0080)
#define	MIPS3_CACHE_ERR_EXC_VEC MIPS_PHYS_TO_KSEG0(0x0100)
#define	MIPS3_GEN_EXC_VEC	MIPS_PHYS_TO_KSEG0(0x0180)

/*
 * MIPS32/MIPS64 (and some MIPS3) dedicated interrupt vector.
 */
#define	MIPS3_INTR_EXC_VEC	MIPS_PHYS_TO_KSEG0(0x0200)

/*
 * Coprocessor 0 registers:
 *
 *				v--- width for mips I,III,32,64
 *				     (3=32bit, 6=64bit, i=impl dep)
 *  0	MIPS_COP_0_TLB_INDEX	3333 TLB Index.
 *  1	MIPS_COP_0_TLB_RANDOM	3333 TLB Random.
 *  2	MIPS_COP_0_TLB_LOW	3... r3k TLB entry low.
 *  2	MIPS_COP_0_TLB_LO0	.636 r4k TLB entry low.
 *  3	MIPS_COP_0_TLB_LO1	.636 r4k TLB entry low, extended.
 *  4	MIPS_COP_0_TLB_CONTEXT	3636 TLB Context.
 *  4/2	MIPS_COP_0_USERLOCAL	..36 UserLocal.
 *  5	MIPS_COP_0_TLB_PG_MASK	.333 TLB Page Mask register.
 *  5/1 MIPS_COP_0_PG_GRAIN	..33 PageGrain register.
 *  5/5 MIPS_COP_0_PWBASE	..33 Page Walker Base register.
 *  5/6 MIPS_COP_0_PWFIELD	..33 Page Walker Field register.
 *  5/7 MIPS_COP_0_PWSIZE	..33 Page Walker Size register.
 *  6	MIPS_COP_0_TLB_WIRED	.333 Wired TLB number.
 *  6/6	MIPS_COP_0_PWCTL	..33 Page Walker Control register.
 *  6/6	MIPS_COP_0_EIRR		...6 [RMI] Extended Interrupt Request Register.
 *  6/7	MIPS_COP_0_EIMR		...6 [RMI] Extended Interrupt Mask Register.
 *  7	MIPS_COP_0_HWRENA	..33 rdHWR Enable.
 *  8	MIPS_COP_0_BAD_VADDR	3636 Bad virtual address.
 *  9	MIPS_COP_0_COUNT	.333 Count register.
 *  9/6	MIPS_COP_0_CVMCNT	...6 [CAVIUM] CvmCtl register.
 *  9/7	MIPS_COP_0_CVMCTL	...6 [CAVIUM] CvmCount register (64 bit).
 * 10	MIPS_COP_0_TLB_HI	3636 TLB entry high.
 * 11	MIPS_COP_0_COMPARE	.333 Compare (against Count).
 * 11/7	MIPS_COP_0_CVMMEMCTL	...6 [CAVIUM] CvmMemCtl register.
 * 12	MIPS_COP_0_STATUS	3333 Status register.
 * 12/1	MIPS_COP_0_INTCTL	..33 Interrupt Control.
 * 12/2	MIPS_COP_0_SRSCTL	..33 Shadow Register Set Selectors.
 * 12/3	MIPS_COP_0_SRSMAP	..33 Shadow Set Map.
 * 13	MIPS_COP_0_CAUSE	3333 Exception cause register.
 * 14	MIPS_COP_0_EXC_PC	3636 Exception PC.
 * 15	MIPS_COP_0_PRID		3333 Processor revision identifier.
 * 15/1	MIPS_COP_0_EBASE	..33 Exception Base.
 * 16	MIPS_COP_0_CONFIG	3333 Configuration register.
 * 16/1	MIPS_COP_0_CONFIG1	..33 Configuration register 1.
 * 16/2	MIPS_COP_0_CONFIG2	..33 Configuration register 2.
 * 16/3	MIPS_COP_0_CONFIG3	..33 Configuration register 3.
 * 16/4	MIPS_COP_0_CONFIG4	..33 Configuration register 6.
 * 16/5	MIPS_COP_0_CONFIG5	..33 Configuration register 7.
 * 16/6	MIPS_COP_0_CONFIG6	..33 Configuration register 6.
 * 16/6	MIPS_COP_0_CVMMEMCTL2	...6 [CAVIUM] CvmMemCtl2 register.
 * 16/7	MIPS_COP_0_CONFIG7	..33 Configuration register 7.
 * 16/7	MIPS_COP_0_CVMVMCONFIG	...6 [CAVIUM] CvmVMConfig register.
 * 17	MIPS_COP_0_LLADDR	.336 Load Linked Address.
 * 18	MIPS_COP_0_WATCH_LO	.336 WatchLo register.
 * 18/1	MIPS_COP_0_WATCH_LO2	..ii WatchLo 1 register.
 * 19	MIPS_COP_0_WATCH_HI	.333 WatchHi register.
 * 19/1	MIPS_COP_0_WATCH_HI1	..ii WatchHi 1 register.
 * 20	MIPS_COP_0_TLB_XCONTEXT .6.6 TLB XContext register.
 * 22	MIPS_COP_0_OSSCRATCH	...6 [RMI] OS Scratch register. (select 0..7)
 * 22	MIPS_COP_0_DIAG		...6 [LOONGSON2] Diagnostic register.
 * 22	MIPS_COP_0_MCD		...6 [CAVIUM] Multi-Core Debug register.
 * 23	MIPS_COP_0_DEBUG	.... Debug JTAG register.
 * 24	MIPS_COP_0_DEPC		.... DEPC JTAG register.
 * 25/0	MIPS_COP_0_PERFCNT0_CTL	..ii Performance Counter 0 control register.
 * 25/1	MIPS_COP_0_PERFCNT0_CNT	..ii Performance Counter 0 value register.
 * 25/2	MIPS_COP_0_PERFCNT1_CTL	..ii Performance Counter 1 control register.
 * 25/3	MIPS_COP_0_PERFCNT1_CNT	..ii Performance Counter 1 value register.
 * 25/4	MIPS_COP_0_PERFCNT0_CTL	..ii Performance Counter 2 control register.
 * 25/5	MIPS_COP_0_PERFCNT0_CNT	..ii Performance Counter 2 value register.
 * 25/6	MIPS_COP_0_PERFCNT1_CTL	..ii Performance Counter 3 control register.
 * 25/7	MIPS_COP_0_PERFCNT1_CNT	..ii Performance Counter 3 value register.
 * 26	MIPS_COP_0_ECC		.3ii ECC / Error Control register.
 * 27	MIPS_COP_0_CACHE_ERR	.3ii Cache Error register.
 * 27	MIPS_COP_0_CACHE_ERR_I	...6 [CAVIUM] Cache Error register (instr).
 * 27/1	MIPS_COP_0_CACHE_ERR_D	...6 [CAVIUM] Cache Error register (data).
 * 27/1	MIPS_COP_0_CACHE_ERR	.3ii Cache Error register.
 * 28/0	MIPS_COP_0_TAG_LO	.3ii Cache TagLo register (instr).
 * 28/1	MIPS_COP_0_DATA_LO	..ii Cache DataLo register (instr).
 * 28/2	MIPS_COP_0_TAG_LO	..ii Cache TagLo register (data).
 * 28/3	MIPS_COP_0_DATA_LO	..ii Cache DataLo register (data).
 * 29/0	MIPS_COP_0_TAG_HI	.3ii Cache TagHi register (instr).
 * 29/1	MIPS_COP_0_DATA_HI	..ii Cache DataHi register (instr).
 * 29/2	MIPS_COP_0_TAG_HI_DATA	..ii Cache TagHi register (data).
 * 29/3	MIPS_COP_0_DATA_HI_DATA	..ii Cache DataHi register (data).
 * 30	MIPS_COP_0_ERROR_PC	.636 Error EPC register.
 * 31	MIPS_COP_0_DESAVE	.... DESAVE JTAG register.
 */
#ifdef _LOCORE
#define	_(n)	__CONCAT($,n)
#else
#define	_(n)	n
#endif
#define	MIPS_COP_0_TLB_INDEX	_(0)
#define	MIPS_COP_0_TLB_RANDOM	_(1)
	/* Name and meaning of	TLB bits for $2 differ on r3k and r4k. */

#define	MIPS_COP_0_TLB_CONTEXT	_(4)
					/* $5 and $6 new with MIPS-III */
#define	MIPS_COP_0_BAD_VADDR	_(8)
#define	MIPS_COP_0_TLB_HI	_(10)
#define	MIPS_COP_0_STATUS	_(12)
#define	MIPS_COP_0_CAUSE	_(13)
#define	MIPS_COP_0_EXC_PC	_(14)
#define	MIPS_COP_0_PRID		_(15)

/* MIPS-I */
#define	MIPS_COP_0_TLB_LOW	_(2)

/* MIPS-III */
#define	MIPS_COP_0_TLB_LO0	_(2)
#define	MIPS_COP_0_TLB_LO1	_(3)

#define	MIPS_COP_0_TLB_PG_MASK	_(5)
#define	MIPS_COP_0_TLB_WIRED	_(6)

#define	MIPS_COP_0_COUNT	_(9)
#define	MIPS_COP_0_COMPARE	_(11)

#define	MIPS_COP_0_CONFIG	_(16)
#define	MIPS_COP_0_LLADDR	_(17)
#define	MIPS_COP_0_WATCH_LO	_(18)
#define	MIPS_COP_0_WATCH_LO1	_(18), 1	/* MIPS32/64 optional */
#define	MIPS_COP_0_WATCH_HI	_(19)
#define	MIPS_COP_0_WATCH_HI1	_(19), 1	/* MIPS32/64 optional */
#define	MIPS_COP_0_TLB_XCONTEXT _(20)
#define	MIPS_COP_0_ECC		_(26)
#define	MIPS_COP_0_CACHE_ERR	_(27)
#define	MIPS_COP_0_CACHE_ERR_I	_(27)		/* CAVIUM */
#define	MIPS_COP_0_CACHE_ERR_D	_(27), 1	/* CAVIUM */
#define	MIPS_COP_0_TAG_LO	_(28)
#define	MIPS_COP_0_TAG_HI	_(29)
#define	MIPS_COP_0_TAG_HI_DATA	_(29), 2
#define	MIPS_COP_0_ERROR_PC	_(30)

/* MIPS32/64 */
#define	MIPS_COP_0_CTXCONFIG	_(4), 1
#define	MIPS_COP_0_USERLOCAL	_(4), 2
#define	MIPS_COP_0_XCTXCONFIG	_(4), 3		/* MIPS64 */
#define	MIPS_COP_0_PGGRAIN	_(5), 1
#define	MIPS_COP_0_SEGCTL0	_(5), 2
#define	MIPS_COP_0_SEGCTL1	_(5), 3
#define	MIPS_COP_0_SEGCTL2	_(5), 4
#define	MIPS_COP_0_PWBASE	_(5), 5
#define	MIPS_COP_0_PWFIELD	_(5), 6
#define	MIPS_COP_0_PWSIZE	_(5), 7
#define	MIPS_COP_0_PWCTL	_(6), 6
#define	MIPS_COP_0_EIRR		_(6), 6		/* RMI */
#define	MIPS_COP_0_EIMR		_(6), 7		/* RMI */
#define	MIPS_COP_0_HWRENA	_(7)
#define	MIPS_COP_0_BADINSTR	_(8), 1
#define	MIPS_COP_0_BADINSTRP	_(8), 2
#define	MIPS_COP_0_CVMCNT	_(9), 6		/* CAVIUM */
#define	MIPS_COP_0_CVMCTL	_(9), 7		/* CAVIUM */
#define	MIPS_COP_0_CVMMEMCTL	_(11), 7	/* CAVIUM */
#define	MIPS_COP_0_INTCTL	_(12), 1
#define	MIPS_COP_0_SRSCTL	_(12), 2
#define	MIPS_COP_0_SRSMAP	_(12), 3
#define	MIPS_COP_0_NESTEDEXC	_(13), 5
#define	MIPS_COP_0_NESTED_EPC	_(14), 2
#define	MIPS_COP_0_EBASE	_(15), 1
#define	MIPS_COP_0_CDMMBASE	_(15), 2
#define	MIPS_COP_0_CMGCRBASE	_(15), 3
#define	MIPS_COP_0_CONFIG1	_(16), 1
#define	MIPS_COP_0_CONFIG2	_(16), 2
#define	MIPS_COP_0_CONFIG3	_(16), 3
#define	MIPS_COP_0_CONFIG4	_(16), 4
#define	MIPS_COP_0_CONFIG5	_(16), 5
#define	MIPS_COP_0_CONFIG6	_(16), 6
#define	MIPS_COP_0_CVMMEMCTL2	_(16), 6	/* CAVIUM */
#define	MIPS_COP_0_CONFIG7	_(16), 7
#define	MIPS_COP_0_CVMVMCONFIG	_(16), 7	/* CAVIUM */
#define	MIPS_COP_0_OSSCRATCH	_(22)		/* RMI */
#define	MIPS_COP_0_DIAG		_(22)		/* LOONGSON2 */
#define	MIPS_COP_0_MCD		_(22)		/* CAVIUM */
#define	MIPS_COP_0_DEBUG	_(23)
#define	MIPS_COP_0_DEPC		_(24)
#define	MIPS_COP_0_PERFCNT0_CTL	_(25)
#define	MIPS_COP_0_PERFCNT0_CNT	_(25), 1
#define	MIPS_COP_0_PERFCNT1_CTL	_(25), 2
#define	MIPS_COP_0_PERFCNT1_CNT	_(25), 3
#define	MIPS_COP_0_PERFCNT2_CTL	_(25), 4
#define	MIPS_COP_0_PERFCNT2_CNT	_(25), 5
#define	MIPS_COP_0_PERFCNT3_CTL	_(25), 6
#define	MIPS_COP_0_PERFCNT3_CNT	_(25), 7
#define	MIPS_COP_0_DATA_LO	_(28), 1
#define	MIPS_COP_0_DATA_HI	_(29), 3
#define	MIPS_COP_0_DATA_HI_DATA	_(29)
#define	MIPS_COP_0_DESAVE	_(31)

#define	MIPS_DIAG_RAS_DISABLE	0x00000001	/* Loongson2 */
#define	MIPS_DIAG_BTB_CLEAR	0x00000002	/* Loongson2 */
#define	MIPS_DIAG_ITLB_CLEAR	0x00000004	/* Loongson2 */

/*
 * Values for the code field in a break instruction.
 */
#define	MIPS_BREAK_INSTR	0x0000000d
#define	MIPS_BREAK_VAL_MASK	0x03ff0000
#define	MIPS_BREAK_VAL_SHIFT	16
#define	MIPS_BREAK_INTOVERFLOW	  6 /* used by gas to indicate int overflow */
#define	MIPS_BREAK_INTDIVZERO	  7 /* used by gas/gcc to indicate int div by zero */
#define	MIPS_BREAK_KDB_VAL	512
#define	MIPS_BREAK_SSTEP_VAL	513
#define	MIPS_BREAK_BRKPT_VAL	514
#define	MIPS_BREAK_SOVER_VAL	515
#define	MIPS_BREAK_KDB		(MIPS_BREAK_INSTR | \
				(MIPS_BREAK_KDB_VAL << MIPS_BREAK_VAL_SHIFT))
#define	MIPS_BREAK_SSTEP	(MIPS_BREAK_INSTR | \
				(MIPS_BREAK_SSTEP_VAL << MIPS_BREAK_VAL_SHIFT))
#define	MIPS_BREAK_BRKPT	(MIPS_BREAK_INSTR | \
				(MIPS_BREAK_BRKPT_VAL << MIPS_BREAK_VAL_SHIFT))
#define	MIPS_BREAK_SOVER	(MIPS_BREAK_INSTR | \
				(MIPS_BREAK_SOVER_VAL << MIPS_BREAK_VAL_SHIFT))

/*
 * Minimum and maximum cache sizes.
 */
#define	MIPS_MIN_CACHE_SIZE	(16 * 1024)
#define	MIPS_MAX_CACHE_SIZE	(256 * 1024)
#define	MIPS3_MAX_PCACHE_SIZE	(32 * 1024)	/* max. primary cache size */

/*
 * The floating point version and status registers.
 */
#define	MIPS_FIR	$0	/* FP Implementation and Revision Register */
#define	MIPS_FCSR	$31	/* FP Control/Status Register */

/*
 * The floating point coprocessor status register bits.
 */
#define	MIPS_FCSR_RM		__BITS(1,0)
#define	  MIPS_FCSR_RM_RN	  0	/* round to nearest */
#define	  MIPS_FCSR_RM_RZ	  1	/* round towards zero */
#define	  MIPS_FCSR_RM_RP	  2	/* round towards +infinity */
#define	  MIPS_FCSR_RM_RM	  3	/* round towards -infinity */
#define	MIPS_FCSR_FLAGS		__BITS(6,2)
#define	  MIPS_FCSR_FLAGS_I	  __BIT(2)	/* inexact */
#define	  MIPS_FCSR_FLAGS_U	  __BIT(3)	/* underflow */
#define	  MIPS_FCSR_FLAGS_O	  __BIT(4)	/* overflow */
#define	  MIPS_FCSR_FLAGS_Z	  __BIT(5)	/* divide by zero */
#define	  MIPS_FCSR_FLAGS_V	  __BIT(6)	/* invalid operation */
#define	MIPS_FCSR_ENABLES	__BITS(11,7)
#define	  MIPS_FCSR_ENABLES_I	  __BIT(7)	/* inexact */
#define	  MIPS_FCSR_ENABLES_U	  __BIT(8)	/* underflow */
#define	  MIPS_FCSR_ENABLES_O	  __BIT(9)	/* overflow */
#define	  MIPS_FCSR_ENABLES_Z	  __BIT(10)	/* divide by zero */
#define	  MIPS_FCSR_ENABLES_V	  __BIT(11)	/* invalid operation */
#define	MIPS_FCSR_CAUSE		__BITS(17,12)
#define	  MIPS_FCSR_CAUSE_I	  __BIT(12)	/* inexact */
#define	  MIPS_FCSR_CAUSE_U	  __BIT(13)	/* underflow */
#define	  MIPS_FCSR_CAUSE_O	  __BIT(14)	/* overflow */
#define	  MIPS_FCSR_CAUSE_Z	  __BIT(15)	/* divide by zero */
#define	  MIPS_FCSR_CAUSE_V	  __BIT(16)	/* invalid operation */
#define	  MIPS_FCSR_CAUSE_E	  __BIT(17)	/* unimplemented operation */
#define	MIPS_FCSR_NAN_2008	__BIT(18)
#define	MIPS_FCSR_ABS_2008	__BIT(19)
#define	MIPS_FCSR_FCC0		__BIT(23)
#define	MIPS_FCSR_FCC		(MIPS_FPU_COND_BIT | __BITS(31,25))
#define	MIPS_FCSR_FS		__BIT(24)	/* r4k+ */


/*
 * Constants to determine if have a floating point instruction.
 */
#define	MIPS_OPCODE_SHIFT	26
#define	MIPS_OPCODE_C1		0x11


/*
 * The low part of the TLB entry.
 */
#define	MIPS1_TLB_PFN			0xfffff000
#define	MIPS1_TLB_NON_CACHEABLE_BIT	0x00000800
#define	MIPS1_TLB_DIRTY_BIT		0x00000400
#define	MIPS1_TLB_VALID_BIT		0x00000200
#define	MIPS1_TLB_GLOBAL_BIT		0x00000100

#define	MIPS3_TLB_PFN			0x3fffffc0
#define	MIPS3_TLB_ATTR_MASK		0x00000038
#define	MIPS3_TLB_ATTR_SHIFT		3
#define	MIPS3_TLB_DIRTY_BIT		0x00000004
#define	MIPS3_TLB_VALID_BIT		0x00000002
#define	MIPS3_TLB_GLOBAL_BIT		0x00000001

#define	MIPS1_TLB_PHYS_PAGE_SHIFT	12
#define	MIPS3_TLB_PHYS_PAGE_SHIFT	6
#define	MIPS1_TLB_PF_NUM		MIPS1_TLB_PFN
#define	MIPS3_TLB_PF_NUM		MIPS3_TLB_PFN
#define	MIPS1_TLB_MOD_BIT		MIPS1_TLB_DIRTY_BIT
#define	MIPS3_TLB_MOD_BIT		MIPS3_TLB_DIRTY_BIT

/*
 * MIPS3_TLB_ATTR (CCA) values - coherency algorithm:
 * 0: cacheable, noncoherent, write-through, no write allocate
 * 1: cacheable, noncoherent, write-through, write allocate
 * 2: uncached
 * 3: cacheable, noncoherent, write-back (noncoherent)
 * 4: cacheable, coherent, write-back, exclusive (exclusive)
 * 5: cacheable, coherent, write-back, exclusive on write (sharable)
 * 6: cacheable, coherent, write-back, update on write (update)
 * 7: uncached, accelerated (gather STORE operations)
 */
#define	MIPS3_TLB_ATTR_WT		0 /* IDT */
#define	MIPS3_TLB_ATTR_WT_WRITEALLOCATE 1 /* IDT */
#define	MIPS3_TLB_ATTR_UNCACHED		2 /* R4000/R4400, IDT */
#define	MIPS3_TLB_ATTR_WB_NONCOHERENT	3 /* R4000/R4400, IDT */
#define	MIPS3_TLB_ATTR_WB_EXCLUSIVE	4 /* R4000/R4400 */
#define	MIPS3_TLB_ATTR_WB_SHARABLE	5 /* R4000/R4400 */
#define	MIPS3_TLB_ATTR_WB_UPDATE	6 /* R4000/R4400 */
#define	MIPS4_TLB_ATTR_UNCACHED_ACCELERATED 7 /* R10000 */


/*
 * The high part of the TLB entry.
 */
#define	MIPS1_TLB_VPN			0xfffff000
#define	MIPS1_TLB_PID			0x00000fc0
#define	MIPS1_TLB_PID_SHIFT		6

#define	MIPS3_TLB_VPN2			0xffffe000
#define	MIPS3_TLB_EHINV			0x00000400	/* mipsNN R3 */
#define	MIPS3_TLB_ASID			0x000000ff

#define	MIPS1_TLB_VIRT_PAGE_NUM		MIPS1_TLB_VPN
#define	MIPS3_TLB_VIRT_PAGE_NUM		MIPS3_TLB_VPN2
#define	MIPS3_TLB_PID			MIPS3_TLB_ASID
#define	MIPS_TLB_VIRT_PAGE_SHIFT	12

/*
 * r3000: shift count to put the index in the right spot.
 */
#define	MIPS1_TLB_INDEX_SHIFT		8

/*
 * The first TLB that write random hits.
 */
#define	MIPS1_TLB_FIRST_RAND_ENTRY	8
#define	MIPS3_TLB_WIRED_UPAGES		1

/*
 * The number of process id entries.
 */
#define	MIPS1_TLB_NUM_PIDS		64
#define	MIPS3_TLB_NUM_ASIDS		256

/*
 * Patch codes to hide CPU design differences between MIPS1 and MIPS3.
 */

/* XXX simonb: this is before MIPS3_PLUS is defined (and is ugly!) */

#if (MIPS3 + MIPS4 + MIPS32 + MIPS32R2 + MIPS64 + MIPS64R2) == 0 && MIPS1 != 0
#define	MIPS_TLB_PID_SHIFT		MIPS1_TLB_PID_SHIFT
#define	MIPS_TLB_PID			MIPS1_TLB_PID
#define	MIPS_TLB_NUM_PIDS		MIPS1_TLB_NUM_PIDS
#endif

#if (MIPS3 + MIPS4 + MIPS32 + MIPS32R2 + MIPS64 + MIPS64R2) != 0 && MIPS1 == 0
#define	MIPS_TLB_PID_SHIFT		0
#define	MIPS_TLB_PID			MIPS3_TLB_PID
#define	MIPS_TLB_NUM_PIDS		MIPS3_TLB_NUM_ASIDS
#endif


#if !defined(MIPS_TLB_PID_SHIFT)
#define	MIPS_TLB_PID_SHIFT \
    ((MIPS_HAS_R4K_MMU) ? 0 : MIPS1_TLB_PID_SHIFT)

#define	MIPS_TLB_PID \
    ((MIPS_HAS_R4K_MMU) ? MIPS3_TLB_PID : MIPS1_TLB_PID)

#define	MIPS_TLB_NUM_PIDS \
    ((MIPS_HAS_R4K_MMU) ? MIPS3_TLB_NUM_ASIDS : MIPS1_TLB_NUM_PIDS)
#endif

/*
 * WatchLo/WatchHi watchpoint registers
 */
#define	MIPS_WATCHLO_VADDR32		__BITS(31,3)	/* 32-bit addr */
#define	MIPS_WATCHLO_VADDR64		__BITS(63,3)	/* 64-bit addr */
#define	MIPS_WATCHLO_INSN		__BIT(2)
#define	MIPS_WATCHLO_DATA_READ		__BIT(1)
#define	MIPS_WATCHLO_DATA_WRITE		__BIT(0)

#define	MIPS_WATCHHI_M			__BIT(31)	/* next watch reg implemented */
#define	MIPS_WATCHHI_G			__BIT(30)	/* use WatchLo vaddr */
#define	MIPS_WATCHHI_EAS		__BITS(25,24)	/* extended ASID */
#define	MIPS_WATCHHI_ASID		__BITS(23,16)
#define	MIPS_WATCHHI_MASK		__BITS(11,3)
#define	MIPS_WATCHHI_INSN		MIPS_WATCHLO_INSN
#define	MIPS_WATCHHI_DATA_READ		MIPS_WATCHLO_DATA_READ
#define	MIPS_WATCHHI_DATA_WRITE		MIPS_WATCHLO_DATA_WRITE

/*
 * RDHWR register numbers
 */
#define	MIPS_HWR_CPUNUM			_(0)	/* Which CPU are we on? */
#define	MIPS_HWR_SYNCI_STEP		_(1)	/* Address step size for SYNCI */
#define	MIPS_HWR_CC			_(2)	/* Hi-res cycle counter */
#define	MIPS_HWR_CCRES			_(3)	/* Cycle counter resolution */
#define	MIPS_HWR_ULR			_(29)	/* Userlocal */
#define	MIPS_HWR_IMPL30			_(30)	/* Implementation dependent use */
#define	MIPS_HWR_IMPL31			_(31)	/* Implementation dependent use */

/*
 * Bits defined for HWREna (CP0 register 7, select 0).
 */
#define	MIPS_HWRENA_IMPL31		__BIT(MIPS_HWR_IMPL31)
#define	MIPS_HWRENA_IMPL30		__BIT(MIPS_HWR_IMPL30)
#define	MIPS_HWRENA_ULR			__BIT(MIPS_HWR_ULR)
#define	MIPS_HWRENA_CCRES		__BIT(MIPS_HWR_CCRES)
#define	MIPS_HWRENA_CC			__BIT(MIPS_HWR_CC)
#define	MIPS_HWRENA_SYNCI_STEP		__BIT(MIPS_HWR_SYNCI_STEP)
#define	MIPS_HWRENA_CPUNUM		__BIT(MIPS_HWR_CPUNUM)

/*
 * Bits defined for EBASE (CP0 register 15, select 1).
 */
#define	MIPS_EBASE_EXC_BASE_SHIFT	12
#define	MIPS_EBASE_EXC_BASE		__BITS(29, MIPS_EBASE_EXC_BASE_SHIFT)
#define	MIPS_EBASE_CPUNUM		__BITS(9, 0)
#define	MIPS_EBASE_CPUNUM_WIDTH		10	/* used by asm code */

/*
 * Hints for the prefetch instruction
 */

/*
 * Prefetched data is expected to be read (not modified)
 */
#define	PREF_LOAD		0
#define	PREF_LOAD_STREAMED	4	/* but not reused extensively; it */
					/* "streams" through cache.  */
#define	PREF_LOAD_RETAINED	6	/* and reused extensively; it should */
					/* be "retained" in the cache.  */

/*
 * Prefetched data is expected to be stored or modified
 */
#define	PREF_STORE		1
#define	PREF_STORE_STREAMED	5	/* but not reused extensively; it */
					/* "streams" through cache.  */
#define	PREF_STORE_RETAINED	7	/* and reused extensively; it should */
					/* be "retained" in the cache.  */

/*
 * data is no longer expected to be used.  For a WB cache, schedule a
 * writeback of any dirty data and afterwards free the cache lines.
 */
#define	PREF_WB_INV		25
#define	PREF_NUDGE		PREF_WB_INV

/*
 * Prepare for writing an entire cache line without the overhead
 * involved in filling the line from memory.
 */
#define	PREF_PREPAREFORSTORE	30

/*
 * CPU processor revision IDs for company ID == 0 (non mips32/64 chips)
 */
#define	MIPS_R2000	0x01	/* MIPS R2000 			ISA I	*/
#define	MIPS_R3000	0x02	/* MIPS R3000 			ISA I	*/
#define	MIPS_R6000	0x03	/* MIPS R6000 			ISA II	*/
#define	MIPS_R4000	0x04	/* MIPS R4000/R4400 		ISA III */
#define	MIPS_R3LSI	0x05	/* LSI Logic R3000 derivative	ISA I	*/
#define	MIPS_R6000A	0x06	/* MIPS R6000A 			ISA II	*/
#define	MIPS_R3IDT	0x07	/* IDT R3041 or RC36100 	ISA I	*/
#define	MIPS_R10000	0x09	/* MIPS R10000			ISA IV	*/
#define	MIPS_R4200	0x0a	/* NEC VR4200 			ISA III */
#define	MIPS_R4300	0x0b	/* NEC VR4300 			ISA III */
#define	MIPS_R4100	0x0c	/* NEC VR4100 			ISA III */
#define	MIPS_R12000	0x0e	/* MIPS R12000			ISA IV	*/
#define	MIPS_R14000	0x0f	/* MIPS R14000			ISA IV	*/
#define	MIPS_R8000	0x10	/* MIPS R8000 Blackbird/TFP	ISA IV	*/
#define	MIPS_RC32300	0x18	/* IDT RC32334,332,355		ISA 32  */
#define	MIPS_R4600	0x20	/* QED R4600 Orion		ISA III */
#define	MIPS_R4700	0x21	/* QED R4700 Orion		ISA III */
#define	MIPS_R3SONY	0x21	/* Sony R3000 based 		ISA I	*/
#define	MIPS_R4650	0x22	/* QED R4650 			ISA III */
#define	MIPS_TX3900	0x22	/* Toshiba TX39 family		ISA I	*/
#define	MIPS_R5000	0x23	/* MIPS R5000 			ISA IV	*/
#define	MIPS_R3NKK	0x23	/* NKK R3000 based 		ISA I	*/
#define	MIPS_RC32364	0x26	/* IDT RC32364 			ISA 32	*/
#define	MIPS_RM7000	0x27	/* QED RM7000			ISA IV  */
#define	MIPS_RM5200	0x28	/* QED RM5200s 			ISA IV	*/
#define	MIPS_TX4900	0x2d	/* Toshiba TX49 family		ISA III */
#define	MIPS_R5900	0x2e	/* Toshiba R5900 (EECore)	ISA --- */
#define	MIPS_RC64470	0x30	/* IDT RC64474/RC64475 		ISA III */
#define	MIPS_TX7900	0x38	/* Toshiba TX79			ISA III+*/
#define	MIPS_R5400	0x54	/* NEC VR5400 			ISA IV	*/
#define	MIPS_R5500	0x55	/* NEC VR5500 			ISA IV	*/
#define	MIPS_LOONGSON2	0x63	/* ICT Loongson-2		ISA III	*/

/*
 * CPU revision IDs for some prehistoric processors.
 */

/* For MIPS_R3000 */
#define	MIPS_REV_R2000A		0x16	/* R2000A uses R3000 proc revision */
#define	MIPS_REV_R3000		0x20
#define	MIPS_REV_R3000A		0x30

/* For MIPS_TX3900 */
#define	MIPS_REV_TX3912		0x10
#define	MIPS_REV_TX3922		0x30
#define	MIPS_REV_TX3927		0x40

/* For MIPS_R4000 */
#define	MIPS_REV_R4000_A	0x00
#define	MIPS_REV_R4000_B	0x22
#define	MIPS_REV_R4000_C	0x30
#define	MIPS_REV_R4400_A	0x40
#define	MIPS_REV_R4400_B	0x50
#define	MIPS_REV_R4400_C	0x60

/* For MIPS_TX4900 */
#define	MIPS_REV_TX4927		0x22

/* For MIPS_LOONGSON2 */
#define	MIPS_REV_LOONGSON2E	0x02
#define	MIPS_REV_LOONGSON2F	0x03

/*
 * CPU processor revision IDs for company ID == 1 (MIPS)
 */
#define	MIPS_4Kc	0x80	/* MIPS 4Kc			ISA 32  */
#define	MIPS_5Kc	0x81	/* MIPS 5Kc			ISA 64  */
#define	MIPS_20Kc	0x82	/* MIPS 20Kc			ISA 64  */
#define	MIPS_4Kmp	0x83	/* MIPS 4Km/4Kp			ISA 32  */
#define	MIPS_4KEc	0x84	/* MIPS 4KEc			ISA 32  */
#define	MIPS_4KEmp	0x85	/* MIPS 4KEm/4KEp		ISA 32  */
#define	MIPS_4KSc	0x86	/* MIPS 4KSc			ISA 32  */
#define	MIPS_M4K	0x87	/* MIPS M4K			ISA 32  Rel 2 */
#define	MIPS_25Kf	0x88	/* MIPS 25Kf			ISA 64  */
#define	MIPS_5KE	0x89	/* MIPS 5KE			ISA 64  Rel 2 */
#define	MIPS_4KEc_R2	0x90	/* MIPS 4KEc_R2			ISA 32  Rel 2 */
#define	MIPS_4KEmp_R2	0x91	/* MIPS 4KEm/4KEp_R2		ISA 32  Rel 2 */
#define	MIPS_4KSd	0x92	/* MIPS 4KSd			ISA 32  Rel 2 */
#define	MIPS_24K	0x93	/* MIPS 24Kc/24Kf		ISA 32  Rel 2 */
#define	MIPS_34K	0x95	/* MIPS 34K			ISA 32  R2 MT */
#define	MIPS_24KE	0x96	/* MIPS 24KEc			ISA 32  Rel 2 */
#define	MIPS_74K	0x97	/* MIPS 74Kc/74Kf		ISA 32  Rel 2 */
#define	MIPS_1004K	0x99	/* MIPS 1004Kc/1004Kf		ISA 32  Rel 2 */
#define	MIPS_1074K	0x9a	/* MIPS 1074Kc/1074Kf		ISA 32  Rel 2 */
#define	MIPS_interAptiv	0xa1	/* MIPS interAptiv		ISA 32  R3 MT */

/*
 * CPU processor revision IDs for company ID == 2 (Broadcom)
 */
#define	MIPS_BCM3302	0x90	/* MIPS 4KEc_R2-like?		ISA 32  Rel 2 */

/*
 * Alchemy (company ID 3) use the processor ID field to denote the CPU core
 * revision and the company options field do donate the SOC chip type.
 */
/* CPU processor revision IDs */
#define	MIPS_AU_REV1	0x01	/* Alchemy Au1000 (Rev 1)	ISA 32  */
#define	MIPS_AU_REV2	0x02	/* Alchemy Au1000 (Rev 2)	ISA 32  */
/* CPU company options IDs */
#define	MIPS_AU1000	0x00
#define	MIPS_AU1500	0x01
#define	MIPS_AU1100	0x02
#define	MIPS_AU1550	0x03

/*
 * CPU processor revision IDs for company ID == 4 (SiByte)
 */
#define	MIPS_SB1	0x01	/* SiByte SB1			ISA 64  */
#define	MIPS_SB1_11	0x11	/* SiByte SB1 (rev 0x11)	ISA 64  */

/*
 * CPU processor revision IDs for company ID == 5 (SandCraft)
 */
#define	MIPS_SR7100	0x04	/* SandCraft SR7100 		ISA 64  */

/*
 * CPU revision IDs for company ID == 12 (RMI)
 * note: unlisted Rev values may indicate pre-production silicon
 */
#define	MIPS_XLR_B2	0x04	/* RMI XLR Production Rev B2		*/
#define	MIPS_XLR_C4	0x91	/* RMI XLR Production Rev C4		*/

/*
 * CPU processor IDs for company ID == 12 (RMI)
 */
#define	MIPS_XLR308B	0x06	/* RMI XLR308-B	 		ISA 64  */
#define	MIPS_XLR508B	0x07	/* RMI XLR508-B	 		ISA 64  */
#define	MIPS_XLR516B	0x08	/* RMI XLR516-B	 		ISA 64  */
#define	MIPS_XLR532B	0x09	/* RMI XLR532-B	 		ISA 64  */
#define	MIPS_XLR716B	0x0a	/* RMI XLR716-B	 		ISA 64  */
#define	MIPS_XLR732B	0x0b	/* RMI XLR732-B	 		ISA 64  */
#define	MIPS_XLR732C	0x00	/* RMI XLR732-C	 		ISA 64  */
#define	MIPS_XLR716C	0x02	/* RMI XLR716-C	 		ISA 64  */
#define	MIPS_XLR532C	0x08	/* RMI XLR532-C	 		ISA 64  */
#define	MIPS_XLR516C	0x0a	/* RMI XLR516-C	 		ISA 64  */
#define	MIPS_XLR508C	0x0b	/* RMI XLR508-C	 		ISA 64  */
#define	MIPS_XLR308C	0x0f	/* RMI XLR308-C	 		ISA 64  */
#define	MIPS_XLS616	0x40	/* RMI XLS616	 		ISA 64  */
#define	MIPS_XLS416	0x44	/* RMI XLS416	 		ISA 64  */
#define	MIPS_XLS608	0x4A	/* RMI XLS608	 		ISA 64  */
#define	MIPS_XLS408	0x4E	/* RMI XLS406	 		ISA 64  */
#define	MIPS_XLS404	0x4F	/* RMI XLS404	 		ISA 64  */
#define	MIPS_XLS408LITE	0x88	/* RMI XLS408-Lite		ISA 64  */
#define	MIPS_XLS404LITE	0x8C	/* RMI XLS404-Lite	 	ISA 64  */
#define	MIPS_XLS208	0x8E	/* RMI XLS208	 		ISA 64  */
#define	MIPS_XLS204	0x8F	/* RMI XLS204	 		ISA 64  */
#define	MIPS_XLS108	0xCE	/* RMI XLS108	 		ISA 64  */
#define	MIPS_XLS104	0xCF	/* RMI XLS104	 		ISA 64  */

/*
 * CPU processor IDs for company ID == 13 (Cavium)
 */
#define	MIPS_CN38XX	0x00	/* Cavium Octeon CN38XX		ISA 64  */
#define	MIPS_CN31XX	0x01	/* Cavium Octeon CN31XX		ISA 64  */
#define	MIPS_CN30XX	0x02	/* Cavium Octeon CN30XX		ISA 64  */
#define	MIPS_CN58XX	0x03	/* Cavium Octeon CN58XX		ISA 64  */
#define	MIPS_CN56XX	0x04	/* Cavium Octeon CN56XX		ISA 64  */
#define	MIPS_CN50XX	0x06	/* Cavium Octeon CN50XX		ISA 64  */
#define	MIPS_CN52XX	0x07	/* Cavium Octeon CN52XX		ISA 64  */
#define	MIPS_CN63XX	0x90	/* Cavium Octeon CN63XX		ISA 64  */
#define	MIPS_CN68XX	0x91	/* Cavium Octeon CN68XX		ISA 64  */
#define	MIPS_CN66XX	0x92	/* Cavium Octeon CN66XX		ISA 64  */
#define	MIPS_CN61XX	0x93	/* Cavium Octeon CN61XX		ISA 64  */
#define	MIPS_CNF71XX	0x94	/* Cavium Octeon CNF71XX	ISA 64  */
#define	MIPS_CN78XX	0x95	/* Cavium Octeon CN78XX		ISA 64  */
#define	MIPS_CN70XX	0x96	/* Cavium Octeon CN70XX		ISA 64  */
#define	MIPS_CN73XX	0x97	/* Cavium Octeon CN73XX		ISA 64  */
#define	MIPS_CNF75XX	0x98	/* Cavium Octeon CNF75XX	ISA 64  */

/*
 * CPU processor revision IDs for company ID == 7 (Microsoft)
 */
#define	MIPS_eMIPS	0x04	/* MSR's eMIPS */

/*
 * CPU processor revision IDs for company ID == e1 (Ingenic)
 */
#define	MIPS_XBURST	0x02	/* Ingenic XBurst */

/*
 * FPU processor revision ID
 */
#define	MIPS_SOFT	0x00	/* Software emulation		ISA I	*/
#define	MIPS_R2360	0x01	/* MIPS R2360 FPC		ISA I	*/
#define	MIPS_R2010	0x02	/* MIPS R2010 FPC		ISA I	*/
#define	MIPS_R3010	0x03	/* MIPS R3010 FPC		ISA I	*/
#define	MIPS_R6010	0x04	/* MIPS R6010 FPC		ISA II	*/
#define	MIPS_R4010	0x05	/* MIPS R4010 FPC		ISA II	*/
#define	MIPS_R31LSI	0x06	/* LSI Logic derivate		ISA I	*/
#define	MIPS_R3TOSH	0x22	/* Toshiba R3000 based FPU	ISA I	*/

#ifdef ENABLE_MIPS_TX3900
#include <mips/r3900regs.h>
#endif
#ifdef MIPS64_SB1
#include <mips/sb1regs.h>
#endif
#if defined(MIPS64_XLP) || defined(MIPS64_XLR) || defined(MIPS64_XLS)
#include <mips/rmi/rmixlreg.h>
#endif

#ifdef MIPS3_LOONGSON2
/*
 * Loongson 2E/2F specific defines
 */

/*
 * Address Window registers physical addresses
 *
 * The Loongson 2F processor has an AXI crossbar with four possible bus
 * masters, each one having four programmable address windows.
 *
 * Each window is defined with three 64-bit registers:
 * - a base address register, defining the address in the master address
 *	space (base register).
 * - an address mask register, defining which address bits are valid in this
 *	window.	A given address matches a window if (addr & mask) == base.
 * - the location of the window base in the target, as well at the target
 *	number itself (mmap register). The lower 20 bits of the address are
 *	forced as zeroes regardless of their value in this register.
 *	The translated address is thus (addr & ~mask) | (mmap & ~0xfffff).
 */

#define	LOONGSON_AWR_BASE_ADDRESS	0x3ff00000ULL

#define	LOONGSON_AWR_BASE(master, window) \
	(LOONGSON_AWR_BASE_ADDRESS + (window) * 0x08 + (master) * 0x60 + 0x00)
#define	LOONGSON_AWR_SIZE(master, window) \
	(LOONGSON_AWR_BASE_ADDRESS + (window) * 0x08 + (master) * 0x60 + 0x20)
#define	LOONGSON_AWR_MMAP(master, window) \
	(LOONGSON_AWR_BASE_ADDRESS + (window) * 0x08 + (master) * 0x60 + 0x40)

/*
 * Bits in the diagnostic register
 */

#define	COP_0_DIAG_ITLB_CLEAR	0x04
#define	COP_0_DIAG_BTB_CLEAR	0x02
#define	COP_0_DIAG_RAS_DISABLE	0x01

#endif /* MIPS3_LOONGSON2 */

#endif /* _MIPS_CPUREGS_H_ */