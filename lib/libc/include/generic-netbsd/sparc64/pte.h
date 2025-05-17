/*	$NetBSD: pte.h,v 1.28 2016/11/04 05:41:01 macallan Exp $ */

/*
 * Copyright (c) 1996-1999 Eduardo Horvath
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *  
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR  ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR  BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 */

#ifndef _MACHINE_PTE_H_
#define _MACHINE_PTE_H_

#if defined(_KERNEL_OPT)
#include "opt_sparc_arch.h"
#endif

/*
 * Address translation works as follows:
 *
 **
 * For sun4u:
 *	
 *	Take your pick; it's all S/W anyway.  We'll start by emulating a sun4.
 *	Oh, here's the sun4u TTE for reference:
 *
 *	struct sun4u_tte {
 *		uint64	tag_g:1,	(global flag)
 *			tag_reserved:2,	(reserved for future use)
 *			tag_ctxt:13,	(context for mapping)
 *			tag_unassigned:6,
 *			tag_va:42;	(virtual address bits<64:22>)
 *		uint64	data_v:1,	(valid bit)
 *			data_size:2,	(page size [8K*8**<SIZE>])
 *			data_nfo:1,	(no-fault only)
 *			data_ie:1,	(invert endianness [inefficient])
 *			data_soft2:9,	(reserved for S/W)
 *			data_reserved:7,(reserved for future use)
 *			data_pa:30,	(physical address)
 *			data_soft:6,	(reserved for S/W)
 *			data_lock:1,	(lock into TLB)
 *			data_cacheable:2,	(cacheability control)
 *			data_e:1,	(explicit accesses only)
 *			data_priv:1,	(privileged page)
 *			data_w:1,	(writable)
 *			data_g:1;	(same as tag_g)
 *	};	
 */

/* virtual address to virtual page number */
#define	VA_SUN4_VPG(va)		(((int)(va) >> 13) & 31)
#define	VA_SUN4C_VPG(va)	(((int)(va) >> 12) & 63)
#define	VA_SUN4U_VPG(va)	(((int)(va) >> 13) & 31)

/* virtual address to offset within page */
#define VA_SUN4_OFF(va)       	(((int)(va)) & 0x1FFF)
#define VA_SUN4C_OFF(va)     	(((int)(va)) & 0xFFF)
#define VA_SUN4U_OFF(va)       	(((int)(va)) & 0x1FFF)

/* When we go to 64-bit VAs we need to handle the hole */
#define VA_VPG(va)	VA_SUN4U_VPG(va)
#define VA_OFF(va)	VA_SUN4U_OFF(va)

#define PG_SHIFT4U	13
#define MMU_PAGE_ALIGN	8192

/* If you know where a tte is in the tsb, how do you find its va? */	
#define TSBVA(i)	((tsb[(i)].tag.f.tag_va<<22)|(((i)<<13)&0x3ff000))

#ifndef _LOCORE
/* 
 *  This is the spitfire TTE.
 *
 *  We could use bitmasks and shifts to construct this if
 *  we had a 64-bit compiler w/64-bit longs.  Otherwise it's
 *  a real pain to do this in C.
 */
#if 0
/* We don't use bitfeilds anyway. */
struct sun4u_tag_fields {
	uint64_t tag_g:1,	/* global flag */
		tag_reserved:2,	/* reserved for future use */
		tag_ctxt:13,	/* context for mapping */
		tag_unassigned:6,
		tag_va:42;	/* virtual address bits<64:22> */
};
union sun4u_tag { struct sun4u_tag_fields f; int64_t tag; };
struct sun4u_data_fields {
	uint64_t data_v:1,	/* valid bit */
		data_size:2,	/* page size [8K*8**<SIZE>] */
		data_nfo:1,	/* no-fault only */
		data_ie:1,	/* invert endianness [inefficient] */
		data_soft2:9,	/* reserved for S/W */
		data_reserved:7,/* reserved for future use */
		data_pa:30,	/* physical address */
		data_tsblock:1,	/* S/W TSB locked entry */
		data_modified:1,/* S/W modified bit */
		data_realw:1,	/* S/W real writable bit (to manage modified) */
		data_accessed:1,/* S/W accessed bit */
		data_exec:1,	/* S/W Executable */
		data_onlyexec:1,/* S/W Executable only */
		data_lock:1,	/* lock into TLB */
		data_cacheable:2,	/* cacheability control */
		data_e:1,	/* explicit accesses only */
		data_priv:1,	/* privileged page */
		data_w:1,	/* writable */
		data_g:1;	/* same as tag_g */
};
union sun4u_data { struct sun4u_data_fields f; int64_t data; };
struct sun4u_tte {
	union sun4u_tag tag;
	union sun4u_data data;
};
#else
struct sun4u_tte {
	int64_t tag;
	int64_t data;
};
#endif
typedef struct sun4u_tte pte_t;

#endif /* _LOCORE */

/* TSB tag masks */
#define CTX_MASK		((1<<13)-1)
#define TSB_TAG_CTX_SHIFT	48
#define TSB_TAG_VA_SHIFT	22
#define TSB_TAG_G		0x8000000000000000LL

#define TSB_TAG_CTX(t)		((((int64_t)(t))>>TSB_TAG_CTX_SHIFT)&CTX_MASK)
#define TSB_TAG_VA(t)		((((int64_t)(t))<<TSB_TAG_VA_SHIFT))
#define TSB_TAG(g,ctx,va)	((((uint64_t)((g)!=0))<<63)|(((uint64_t)(ctx)&CTX_MASK)<<TSB_TAG_CTX_SHIFT)|(((uint64_t)va)>>TSB_TAG_VA_SHIFT))

/* Page sizes */
#define	PGSZ_8K			0
#define	PGSZ_64K		1
#define	PGSZ_512K		2
#define	PGSZ_4M			3

#define	SUN4U_PGSZ_SHIFT	61
#define	SUN4U_TLB_SZ(s)		(((uint64_t)(s))<<SUN4U_PGSZ_SHIFT)

/* TLB data masks */
#define SUN4U_TLB_V		0x8000000000000000LL
#define SUN4U_TLB_8K		SUN4U_TLB_SZ(PGSZ_8K)
#define SUN4U_TLB_64K		SUN4U_TLB_SZ(PGSZ_64K)
#define SUN4U_TLB_512K		SUN4U_TLB_SZ(PGSZ_512K)
#define SUN4U_TLB_4M		SUN4U_TLB_SZ(PGSZ_4M)
#define SUN4U_TLB_SZ_MASK	0x6000000000000000LL
#define SUN4U_TLB_NFO		0x1000000000000000LL
#define SUN4U_TLB_IE		0x0800000000000000LL
#define SUN4U_TLB_SOFT2_MASK	0x07fc000000000000LL
#define SUN4U_TLB_RESERVED_MASK	0x0003f80000000000LL
#define SUN4U_TLB_PA_MASK	0x000007ffffffe000LL
#define SUN4U_TLB_SOFT_MASK	0x0000000000001f80LL
/* S/W bits */
/* Access & TSB locked bits are swapped so I can set access w/one insn */
/* #define SUN4U_TLB_ACCESS	0x0000000000001000LL */
#define SUN4U_TLB_ACCESS	0x0000000000000200LL
#define SUN4U_TLB_MODIFY	0x0000000000000800LL
#define SUN4U_TLB_REAL_W	0x0000000000000400LL
/* #define SUN4U_TLB_TSB_LOCK	0x0000000000000200LL */
#define SUN4U_TLB_TSB_LOCK	0x0000000000001000LL
#define SUN4U_TLB_EXEC		0x0000000000000100LL
#define SUN4U_TLB_EXEC_ONLY	0x0000000000000080LL
/* H/W bits */
#define SUN4U_TLB_L		0x0000000000000040LL
#define SUN4U_TLB_CACHE_MASK	0x0000000000000030LL
#define SUN4U_TLB_CP		0x0000000000000020LL
#define SUN4U_TLB_CV		0x0000000000000010LL
#define SUN4U_TLB_E		0x0000000000000008LL
#define SUN4U_TLB_P		0x0000000000000004LL
#define SUN4U_TLB_W		0x0000000000000002LL
#define SUN4U_TLB_G		0x0000000000000001LL

/* Use a bit in the SOFT2 area to indicate a locked mapping. */
#define	TLB_WIRED		0x0010000000000000LL

/* 
 * The following bits are used by locore so they should
 * be duplicates of the above w/o the "long long"
 */
/* S/W bits */
/* #define SUN4U_TTE_ACCESS	0x0000000000001000 */
#define SUN4U_TTE_ACCESS	0x0000000000000200
#define SUN4U_TTE_MODIFY	0x0000000000000800
#define SUN4U_TTE_REAL_W	0x0000000000000400
/* #define SUN4U_TTE_TSB_LOCK	0x0000000000000200 */
#define SUN4U_TTE_TSB_LOCK	0x0000000000001000
#define SUN4U_TTE_EXEC		0x0000000000000100
#define SUN4U_TTE_EXEC_ONLY	0x0000000000000080
/* H/W bits */
#define SUN4U_TTE_L		0x0000000000000040
#define SUN4U_TTE_CACHE_MASK	0x0000000000000030
#define SUN4U_TTE_CP		0x0000000000000020
#define SUN4U_TTE_CV		0x0000000000000010
#define SUN4U_TTE_E		0x0000000000000008
#define SUN4U_TTE_P		0x0000000000000004
#define SUN4U_TTE_W		0x0000000000000002
#define SUN4U_TTE_G		0x0000000000000001

#define TTE_DATA_BITS	"\177\20" \
        "b\77V\0" "f\75\2SIZE\0" "b\77V\0" "f\75\2SIZE\0" \
        "=\0008K\0" "=\00164K\0" "=\002512K\0" "=\0034M\0" \
        "b\74NFO\0"     "b\73IE\0"      "f\62\10SOFT2\0" \
        "f\51\10DIAG\0" "f\15\33PA<40:13>\0" "f\7\5SOFT\0" \
        "b\6L\0"        "b\5CP\0"       "b\4CV\0" \
        "b\3E\0"        "b\2P\0"        "b\1W\0"        "b\0G\0"

#define SUN4V_PGSZ_SHIFT	0
#define	SUN4V_TLB_SZ(s)		(((uint64_t)(s))<<SUN4V_PGSZ_SHIFT)

/* TLB data masks */
#define SUN4V_TLB_V		0x8000000000000000LL
#define SUN4V_TLB_8K		SUN4V_TLB_SZ(PGSZ_8K)
#define SUN4V_TLB_64K		SUN4V_TLB_SZ(PGSZ_64K)
#define SUN4V_TLB_512K		SUN4V_TLB_SZ(PGSZ_512K)
#define SUN4V_TLB_4M		SUN4V_TLB_SZ(PGSZ_4M)
#define SUN4V_TLB_SZ_MASK	0x000000000000000fLL
#define SUN4V_TLB_NFO		0x4000000000000000LL
#define SUN4V_TLB_IE		0x0000000000001000LL
#define SUN4V_TLB_SOFT2_MASK	0x3f00000000000000LL
#define SUN4V_TLB_PA_MASK	0x00ffffffffffe000LL
#define SUN4V_TLB_SOFT_MASK	0x0000000000000030LL
/* S/W bits */
#define SUN4V_TLB_ACCESS	0x0000000000000010LL
#define SUN4V_TLB_MODIFY	0x0000000000000020LL
#define SUN4V_TLB_REAL_W	0x2000000000000000LL
#define SUN4V_TLB_TSB_LOCK	0x1000000000000000LL
#define SUN4V_TLB_EXEC		SUN4V_TLB_X
#define SUN4V_TLB_EXEC_ONLY	0x0200000000000000LL
/* H/W bits */
#define SUN4V_TLB_CACHE_MASK	0x0000000000000600LL
#define SUN4V_TLB_CP		0x0000000000000400LL
#define SUN4V_TLB_CV		0x0000000000000200LL
#define SUN4V_TLB_E		0x0000000000000800LL
#define SUN4V_TLB_P		0x0000000000000100LL
#define SUN4V_TLB_X		0x0000000000000080LL
#define SUN4V_TLB_W		0x0000000000000040LL
#define SUN4V_TLB_G		0x0000000000000000LL

#define SUN4U_TSB_DATA(g,sz,pa,priv,write,cache,aliased,valid,ie,wc) \
(((valid)?SUN4U_TLB_V:0LL)|SUN4U_TLB_SZ(sz)|(((uint64_t)(pa))&SUN4U_TLB_PA_MASK)|\
((cache)?((aliased)?SUN4U_TLB_CP:SUN4U_TLB_CACHE_MASK):((wc)?0LL:SUN4U_TLB_E))|\
((priv)?SUN4U_TLB_P:0LL)|((write)?SUN4U_TLB_W:0LL)|((g)?SUN4U_TLB_G:0LL)|((ie)?SUN4U_TLB_IE:0LL))

#define SUN4V_TSB_DATA(g,sz,pa,priv,write,cache,aliased,valid,ie,wc) \
(((valid)?SUN4V_TLB_V:0LL)|SUN4V_TLB_SZ(sz)|\
(((u_int64_t)(pa))&SUN4V_TLB_PA_MASK)|\
((cache)?((aliased)?SUN4V_TLB_CP:SUN4V_TLB_CACHE_MASK):((wc)?0LL:SUN4V_TLB_E))|\
((priv)?SUN4V_TLB_P:0LL)|((write)?SUN4V_TLB_W:0LL)|((g)?SUN4V_TLB_G:0LL)|\
((ie)?SUN4V_TLB_IE:0LL))

#define TSB_DATA(g,sz,pa,priv,write,cache,aliased,valid,ie,wc) \
(CPU_ISSUN4V ? SUN4V_TSB_DATA(g,sz,pa,priv,write,cache,aliased,valid,ie,wc) : \
               SUN4U_TSB_DATA(g,sz,pa,priv,write,cache,aliased,valid,ie,wc))

#define TLB_EXEC      (CPU_ISSUN4V ? SUN4V_TLB_EXEC      : SUN4U_TLB_EXEC)
#define TLB_V         (CPU_ISSUN4V ? SUN4V_TLB_V         : SUN4U_TLB_V)
#define TLB_PA_MASK   (CPU_ISSUN4V ? SUN4V_TLB_PA_MASK   : SUN4U_TLB_PA_MASK)
#define TLB_CP        (CPU_ISSUN4V ? SUN4V_TLB_CP        : SUN4U_TLB_CP)
#define TLB_P         (CPU_ISSUN4V ? SUN4V_TLB_P         : SUN4U_TLB_P)
#define TLB_W         (CPU_ISSUN4V ? SUN4V_TLB_W         : SUN4U_TLB_W)
#define TLB_ACCESS    (CPU_ISSUN4V ? SUN4V_TLB_ACCESS    : SUN4U_TLB_ACCESS)
#define TLB_MODIFY    (CPU_ISSUN4V ? SUN4V_TLB_MODIFY    : SUN4U_TLB_MODIFY)
#define TLB_REAL_W    (CPU_ISSUN4V ? SUN4V_TLB_REAL_W    : SUN4U_TLB_REAL_W)
#define TLB_TSB_LOCK  (CPU_ISSUN4V ? SUN4V_TLB_TSB_LOCK  : SUN4U_TLB_TSB_LOCK)
#define TLB_EXEC_ONLY (CPU_ISSUN4V ? SUN4V_TLB_EXEC_ONLY : SUN4U_TLB_EXEC_ONLY)
#define TLB_L         (CPU_ISSUN4V ? 0                   : SUN4U_TLB_L)
#define TLB_CV        (CPU_ISSUN4V ? SUN4V_TLB_CV        : SUN4U_TLB_CV)
#define TLB_IE        (CPU_ISSUN4V ? SUN4V_TLB_IE        : SUN4U_TLB_IE)

#define MMU_CACHE_VIRT	0x3
#define MMU_CACHE_PHYS	0x2
#define MMU_CACHE_NONE	0x0

/* This needs to be updated for sun4u IOMMUs */
/*
 * IOMMU PTE bits.
 */
#define IOPTE_PPN_MASK  0x07ffff00
#define IOPTE_PPN_SHIFT 8
#define IOPTE_RSVD      0x000000f1
#define IOPTE_WRITE     0x00000004
#define IOPTE_VALID     0x00000002

/*
 * This is purely for compatibility with the old SPARC machines.
 */
#define	NBPRG	(1 << 24)	/* bytes per region */
#define	RGSHIFT	24		/* log2(NBPRG) */
#define NSEGRG	(NBPRG / NBPSG)	/* segments per region */

#define	NBPSG	(1 << 18)	/* bytes per segment */
#define	SGSHIFT	18		/* log2(NBPSG) */

/* there is no `struct pte'; we just use `int'; this is for non-4M only */
#define	PG_V		0x80000000
#define	PG_PFNUM	0x0007ffff	/* n.b.: only 16 bits on sun4c */

/* virtual address to virtual region number */
#define	VA_VREG(va)	(((unsigned int)(va) >> RGSHIFT) & 255)

/* virtual address to virtual segment number */
#define	VA_VSEG(va)	(((unsigned int)(va) >> SGSHIFT) & 63)

#ifndef _LOCORE
typedef u_short pmeg_t;		/* 10 bits needed per Sun-4 segmap entry */
#endif

/*
 * Here are the bit definitions for 4M/SRMMU pte's
 */
		/* MMU TABLE ENTRIES */
#define SRMMU_TETYPE	0x3		/* mask for table entry type */
#define SRMMU_TEPTE	0x2		/* Page Table Entry */
		/* PTE FIELDS */
#define SRMMU_PPNMASK	0xFFFFFF00
#define SRMMU_PPNPASHIFT 0x4 		/* shift to put ppn into PAddr */

#endif /* _MACHINE_PTE_H_ */