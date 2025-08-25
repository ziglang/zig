/*	$NetBSD: pte.h,v 1.33 2022/05/29 10:47:39 andvar Exp $ */

/*
 * Copyright (c) 1996
 * 	The President and Fellows of Harvard College. All rights reserved.
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This software was developed by the Computer Systems Engineering group
 * at Lawrence Berkeley Laboratory under DARPA contract BG 91-66 and
 * contributed to Berkeley.
 *
 * All advertising materials mentioning features or use of this software
 * must display the following acknowledgements:
 * 	This product includes software developed by Harvard University.
 *	This product includes software developed by the University of
 *	California, Lawrence Berkeley Laboratory.
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
 *    must display the following acknowledgements:
 *	This product includes software developed by Harvard University.
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
 *	@(#)pte.h	8.1 (Berkeley) 6/11/93
 */

#ifndef	_SPARC_PTE_H_
#define _SPARC_PTE_H_

#if defined(_KERNEL_OPT)
#include "opt_sparc_arch.h"
#endif

/*
 * Sun-4 (sort of), 4c (SparcStation), and 4m Page Table Entries
 * (Sun calls them `Page Map Entries').
 */

#ifndef _LOCORE
/*
 * Segment maps contain `pmeg' (Page Map Entry Group) numbers.
 * A PMEG is simply an index that names a group of 32 (sun4) or
 * 64 (sun4c) PTEs.
 * Depending on the CPU model, we need 7 (sun4c) to 10 (sun4/400) bits
 * to hold the hardware MMU resource number.
 */
typedef u_short pmeg_t;		/* 10 bits needed per Sun-4 segmap entry */
/*
 * Region maps contain `smeg' (Segment Entry Group) numbers.
 * An SMEG is simply an index that names a group of 64 PMEGs.
 */
typedef u_char smeg_t;		/* 8 bits needed per Sun-4 regmap entry */
#endif

/*
 * Address translation works as follows:
 *
 * (for sun4c and 2-level sun4)
 *	1. test va<31:29> -- these must be 000 or 111 (or you get a fault)
 *	2. concatenate context_reg<2:0> and va<29:18> to get a 15 bit number;
 *	   use this to index the segment maps, yielding a 7 or 9 bit value.
 * (for 3-level sun4)
 *	1. concatenate context_reg<3:0> and va<31:24> to get a 8 bit number;
 *	   use this to index the region maps, yielding a 10 bit value.
 *	2. take the value from (1) above and concatenate va<17:12> to
 *	   get a `segment map entry' index.  This gives a 9 bit value.
 * (for sun4c)
 *	3. take the value from (2) above and concatenate va<17:12> to
 *	   get a `page map entry' index.  This gives a 32-bit PTE.
 * (for sun4)
 *	3. take the value from (2 or 3) above and concatenate va<17:13> to
 *	   get a `page map entry' index.  This gives a 32-bit PTE.
 **
 * For sun4m:
 *	1. Use context_reg<3:0> to index the context table (located at
 *	   (context_reg << 2) | ((ctx_tbl_ptr_reg >> 2) << 6) ). This
 *	   gives a 32-bit page-table-descriptor (PTP).
 *	2. Use va<31:24> to index the region table located by the PTP from (1):
 *	   PTP<31:6> << 10. This gives another PTP for the segment tables
 *	3. Use va<23:18> to index the segment table located by the PTP from (2)
 *	   as follows: PTP<31:4> << 8. This gives another PTP for the page tbl.
 * 	4. Use va<17:12> to index the page table given by (3)'s PTP:
 * 	   PTP<31:4> << 8. This gives a 32-bit PTE.
 *
 * In other words:
 *
 *	struct sun4_3_levelmmu_virtual_addr {
 *		u_int	va_reg:8,	(virtual region)
 *			va_seg:6,	(virtual segment)
 *			va_pg:5,	(virtual page within segment)
 *			va_off:13;	(offset within page)
 *	};
 *	struct sun4_virtual_addr {
 *		u_int	:2,		(required to be the same as bit 29)
 *			va_seg:12,	(virtual segment)
 *			va_pg:5,	(virtual page within segment)
 *			va_off:13;	(offset within page)
 *	};
 *	struct sun4c_virtual_addr {
 *		u_int	:2,		(required to be the same as bit 29)
 *			va_seg:12,	(virtual segment)
 *			va_pg:6,	(virtual page within segment)
 *			va_off:12;	(offset within page)
 *	};
 *
 *	struct sun4m_virtual_addr {
 *		u_int	va_reg:8,	(virtual region)
 *			va_seg:6,	(virtual segment within region)
 *			va_pg:6,	(virtual page within segment)
 *			va_off:12;	(offset within page)
 *	};
 *
 * Then, given any `va':
 *
 *	extern smeg_t regmap[16][1<<8];		(3-level MMU only)
 *	extern pmeg_t segmap[8][1<<12];		([16][1<<12] for sun4)
 *	extern int ptetable[128][1<<6];		([512][1<<5] for sun4)
 *
 *	extern u_int  s4m_ctxmap[16];		(sun4m SRMMU only)
 *	extern u_int  s4m_regmap[16][1<<8];	(sun4m SRMMU only)
 * 	extern u_int  s4m_segmap[1<<8][1<<6];	(sun4m SRMMU only)
 * 	extern u_int  s4m_pagmap[1<<14][1<<6];	(sun4m SRMMU only)
 *
 * (the above being in the hardware, accessed as Alternate Address Spaces on
 *  all machines but the Sun4m SRMMU, in which case the tables are in physical
 *  kernel memory. In the 4m architecture, the tables are not laid out as
 *  2-dim arrays, but are sparsely allocated as needed, and point to each
 *  other.)
 *
 *	if (cputyp==CPU_SUN4M || cputyp==CPU_SUN4D) // SPARC Reference MMU
 *		regptp = s4m_ctxmap[curr_ctx];
 *		if (!(regptp & SRMMU_TEPTD)) TRAP();
 *		segptp = *(u_int *)(((regptp & ~0x3) << 4) | va.va_reg);
 *		if (!(segptp & SRMMU_TEPTD)) TRAP();
 *		pagptp = *(u_int *)(((segptp & ~0x3) << 4) | va.va_seg);
 *		if (!(pagptp & SRMMU_TEPTD)) TRAP();
 *		pte = *(u_int *)(((pagptp & ~0x3) << 4) | va.va_pg);
 *		if (!(pte & SRMMU_TEPTE)) TRAP();       // like PG_V
 * 		if (usermode && PTE_PROT_LEVEL(pte) > 0x5) TRAP();
 *		if (writing && !PTE_PROT_LEVEL_ALLOWS_WRITING(pte)) TRAP();
 *		if (!(pte & SRMMU_PG_C)) DO_NOT_USE_CACHE_FOR_THIS_ACCESS();
 *		pte |= SRMMU_PG_U;
 * 		if (writing) pte |= PG_M;
 * 		physaddr = ((pte & SRMMU_PG_PFNUM) << SRMMU_PGSHIFT)|va.va_off;
 *		return;
 *	if (mmu_3l)
 *		physreg = regmap[curr_ctx][va.va_reg];
 *		physseg = segmap[physreg][va.va_seg];
 *	else
 *		physseg = segmap[curr_ctx][va.va_seg];
 *	pte = ptetable[physseg][va.va_pg];
 *	if (!(pte & PG_V)) TRAP();
 *	if (writing && !pte.pg_w) TRAP();
 *	if (usermode && pte.pg_s) TRAP();
 *	if (pte & PG_NC) DO_NOT_USE_CACHE_FOR_THIS_ACCESS();
 *	pte |= PG_U;					(mark used/accessed)
 *	if (writing) pte |= PG_M;			(mark modified)
 *	ptetable[physseg][va.va_pg] = pte;
 *	physadr = ((pte & PG_PFNUM) << PGSHIFT) | va.va_off;
 */

#if defined(SUN4_MMU3L) && !defined(SUN4)
#error "configuration error"
#endif

#define NBPRG	(1 << 24)	/* bytes per region */
#define RGSHIFT	24		/* log2(NBPRG) */
#define RGOFSET	(NBPRG - 1)	/* mask for region offset */
#define NSEGRG	(NBPRG / NBPSG)	/* segments per region */

#define NBPSG	(1 << 18)	/* bytes per segment */
#define SGSHIFT	18		/* log2(NBPSG) */
#define SGOFSET	(NBPSG - 1)	/* mask for segment offset */

/* number of PTEs that map one segment (not number that fit in one segment!) */
#if defined(SUN4) && (defined(SUN4C) || defined(SUN4M) || defined(SUN4D))
extern int nptesg;
#define NPTESG	nptesg		/* (which someone will have to initialize) */
#else
#define NPTESG	(NBPSG / NBPG)
#endif

/* virtual address to virtual region number */
#define VA_VREG(va)	(((unsigned int)(va) >> RGSHIFT) & 255)

/* virtual address to virtual segment number */
#define VA_VSEG(va)	(((unsigned int)(va) >> SGSHIFT) & 63)

/* virtual address to virtual page number, for Sun-4 and Sun-4c */
#define VA_SUN4_VPG(va)		(((int)(va) >> 13) & 31)
#define VA_SUN4C_VPG(va)	(((int)(va) >> 12) & 63)
#define VA_SUN4M_VPG(va)	(((int)(va) >> 12) & 63)
#define VA_VPG(va)	\
	(PGSHIFT==SUN4_PGSHIFT ? VA_SUN4_VPG(va) : VA_SUN4C_VPG(va))

/* virtual address to offset within page */
#define VA_SUN4_OFF(va)       	(((int)(va)) & 0x1FFF)
#define VA_SUN4C_OFF(va)     	(((int)(va)) & 0xFFF)
#define VA_SUN4M_OFF(va)	(((int)(va)) & 0xFFF)
#define VA_OFF(va)	\
	(PGSHIFT==SUN4_PGSHIFT ? VA_SUN4_OFF(va) : VA_SUN4C_OFF(va))


/* truncate virtual address to region base */
#define VA_ROUNDDOWNTOREG(va)	((int)(va) & ~RGOFSET)

/* truncate virtual address to segment base */
#define VA_ROUNDDOWNTOSEG(va)	((int)(va) & ~SGOFSET)

/* virtual segment to virtual address (must sign extend on holy MMUs!) */
#define VRTOVA(vr)	((CPU_HAS_SRMMU || HASSUN4_MMU3L)	\
	? ((int)(vr) << RGSHIFT)				\
	: (((int)(vr) << (RGSHIFT+2)) >> 2))
#define VSTOVA(vr,vs)	((CPU_HAS_SRMMU || HASSUN4_MMU3L)	\
	? (((int)(vr) << RGSHIFT) + ((int)(vs) << SGSHIFT))	\
	: ((((int)(vr) << (RGSHIFT+2)) >> 2) + ((int)(vs) << SGSHIFT)))

extern int mmu_has_hole;
#define VA_INHOLE(va)	(mmu_has_hole \
	? ( (unsigned int)(((int)(va) >> PG_VSHIFT) + 1) > 1) \
	: 0)

/* Define the virtual address space hole */
#define MMU_HOLE_START	0x20000000
#define MMU_HOLE_END	0xe0000000

/* there is no `struct pte'; we just use `int'; this is for non-4M only */
#define PG_V		0x80000000
#define PG_PROT		0x60000000	/* both protection bits */
#define PG_W		0x40000000	/* allowed to write */
#define PG_S		0x20000000	/* supervisor only */
#define PG_NC		0x10000000	/* non-cacheable */
#define PG_TYPE		0x0c000000	/* both type bits */

#define PG_OBMEM	0x00000000	/* on board memory */
#define PG_OBIO		0x04000000	/* on board I/O (incl. Sbus on 4c) */
#define PG_VME16	0x08000000	/* 16-bit-data VME space */
#define PG_VME32	0x0c000000	/* 32-bit-data VME space */
#if defined(SUN4M) || defined(SUN4D)
#define PG_SUN4M_OBMEM	0x0	       	/* No type bits=>obmem on 4m */
#define PG_SUN4M_OBIO	0xf		/* obio maps to 0xf on 4M */
#define SRMMU_PGTYPE	0xf0000000	/* Top 4 bits of pte PPN give type */
#endif

#define PG_U		0x02000000
#define PG_M		0x01000000
#define PG_MBZ		0x00780000	/* unused; must be zero (oh really?) */
#define PG_IOC		0x00800000	/* IO cache, not used yet */
#define PG_WIRED	0x00400000	/* S/W only; in MBZ area */
#define PG_PFNUM	0x0007ffff	/* n.b.: only 16 bits on sun4c */

#define PG_TNC_SHIFT	26		/* shift to get PG_TYPE + PG_NC */
#define PG_M_SHIFT	24		/* shift to get PG_M, PG_U */
#define PG_M_SHIFT4M	5		/* shift to get SRMMU_PG_M,R on 4m */
/*efine	PG_NOACC	0		** XXX */
#define PG_KR		0x20000000
#define PG_KW		0x60000000
#define PG_URKR		0
#define PG_UW		0x40000000

#ifdef KGDB
/* but we will define one for gdb anyway */
struct pte {
	u_int	pg_v:1,
		pg_w:1,
		pg_s:1,
		pg_nc:1;
	enum pgtype { pg_obmem, pg_obio, pg_vme16, pg_vme32 } pg_type:2;
	u_int	pg_u:1,
		pg_m:1,
		pg_mbz:5,
		pg_pfnum:19;
};
#if defined(SUN4M) || defined(SUN4D)
struct srmmu_pte {
	u_int	pg_pfnum:24,
		pg_c:1,
		pg_m:1,
		pg_u:1;
	enum pgprot { pprot_r_r, pprot_rw_rw, pprot_rx_rx, pprot_rwx_rwx,
		      pprot_x_x, pprot_r_rw, pprot_n_rx, pprot_n_rwx }
		pg_prot:3;	/* prot. bits: pprot_<user>_<supervisor> */
	u_int	pg_must_be_2:2;
};
#endif
#endif

/*
 * These are needed in the register window code
 * to check the validity of (ostensible) user stack PTEs.
 */
#define PG_VSHIFT	29		/* (va>>vshift)==0 or -1 => valid */
	/* XXX fix this name, it is a va shift not a pte bit shift! */

#define PG_PROTSHIFT	29
#define PG_PROTUWRITE	6		/* PG_V,PG_W,!PG_S */
#define PG_PROTUREAD	4		/* PG_V,!PG_W,!PG_S */

/* %%%: Fix above and below for 4m? */

/* static __inline int PG_VALID(void *va) {
	register int t = va; t >>= PG_VSHIFT; return (t == 0 || t == -1);
} */


/*
 * Here are the bit definitions for 4M/SRMMU pte's
 */
		/* MMU TABLE ENTRIES */
#define SRMMU_TEINVALID	0x0		/* invalid (serves as !valid bit) */
#define SRMMU_TEPTD	0x1		/* Page Table Descriptor */
#define SRMMU_TEPTE	0x2		/* Page Table Entry */
#define SRMMU_TEPTERBO	0x3		/* Page Table Entry with Reverse Byte
					   Order (SS-II) */
#define SRMMU_TETYPE	0x3		/* mask for table entry type */
		/* PTE FIELDS */
#define SRMMU_PPNMASK	0xFFFFFF00
#define SRMMU_PPNSHIFT	0x8
#define SRMMU_PPNPASHIFT 0x4 		/* shift to put ppn into PAddr */
#define SRMMU_L1PPNSHFT	0x14
#define SRMMU_L1PPNMASK	0xFFF00000
#define SRMMU_L2PPNSHFT 0xE
#define SRMMU_L2PPNMASK	0xFC000
#define SRMMU_L3PPNSHFT	0x8
#define SRMMU_L3PPNMASK 0x3F00
		/* PTE BITS */
#define SRMMU_PG_C	0x80		/* cacheable */
#define SRMMU_PG_M	0x40		/* modified (dirty) */
#define SRMMU_PG_R	0x20		/* referenced */
#define SRMMU_PGBITSMSK	0xE0
		/* PTE PROTECTION */
#define SRMMU_PROT_MASK	0x1C		/* Mask protection bits out of pte */
#define SRMMU_PROT_SHFT	0x2
#define PPROT_R_R	0x0		/* These are in the form:	*/
#define PPROT_RW_RW	0x4		/* 	PPROT_<u>_<s>		*/
#define PPROT_RX_RX	0x8		/* where <u> is the user-mode	*/
#define PPROT_RWX_RWX	0xC		/* permission, and <s> is the 	*/
#define PPROT_X_X	0x10		/* supervisor mode permission.	*/
#define PPROT_R_RW	0x14		/* R=read, W=write, X=execute	*/
#define PPROT_N_RX	0x18		/* N=none.			*/
#define PPROT_N_RWX	0x1C
#define PPROT_WRITE	0x4		/* set iff write priv. allowed  */
#define PPROT_S		0x18		/* effective S bit */
#define PPROT_U2S_OMASK 0x18		/* OR with prot. to revoke user priv */
		/* TABLE SIZES */
#define SRMMU_L1SIZE	0x100
#define SRMMU_L2SIZE 	0x40
#define SRMMU_L3SIZE	0x40

#define SRMMU_PTE_BITS	"\177\020"					\
	"f\0\2TYPE\0=\1PTD\0=\2PTE\0f\2\3PROT\0"			\
	"=\0R_R\0=\4RW_RW\0=\10RX_RX\0=\14RWX_RWX\0=\20X_X\0=\24R_RW\0"	\
	"=\30N_RX\0=\34N_RWX\0"						\
	"b\5R\0b\6M\0b\7C\0f\10\30PFN\0"

/*
 * IOMMU PTE bits.
 */
#define IOPTE_PPN_MASK  0x07ffff00
#define IOPTE_PPN_SHIFT 8
#define IOPTE_RSVD      0x000000f1
#define IOPTE_WRITE     0x00000004
#define IOPTE_VALID     0x00000002

#define IOMMU_PTE_BITS	"\177\020"					\
	"f\10\23PPN\0b\2W\0b\1V\0"


#if defined(_KERNEL) || defined(_STANDALONE)
/*
 * Macros to get and set the processor context.
 */
#define getcontext4()		lduba(AC_CONTEXT, ASI_CONTROL)
#define getcontext4m()		lda(SRMMU_CXR, ASI_SRMMU)
#define getcontext()		(CPU_HAS_SRMMU ? getcontext4m()		\
					       : getcontext4())

#define setcontext4(c)		stba(AC_CONTEXT, ASI_CONTROL, c)
#define setcontext4m(c)		sta(SRMMU_CXR, ASI_SRMMU, c)
#define setcontext(c)		(CPU_HAS_SRMMU ? setcontext4m(c)	\
					       : setcontext4(c))

/* sun4/sun4c access to MMU-resident PTEs */
#define getpte4(va)		lda(va, ASI_PTE)
#define setpte4(va, pte)	sta(va, ASI_PTE, pte)

/* sun4m TLB probe */
#define getpte4m(va)		lda((va & 0xFFFFF000) | ASI_SRMMUFP_L3, \
				    ASI_SRMMUFP)

#endif /* _KERNEL || _STANDALONE */
#endif /* _SPARC_PTE_H_ */