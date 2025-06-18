/*	$NetBSD: ctlreg.h,v 1.67 2019/11/13 10:06:38 nakayama Exp $ */

/*
 * Copyright (c) 1996-2002 Eduardo Horvath
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

#ifndef _SPARC_CTLREG_H_
#define _SPARC_CTLREG_H_

/*
 * Sun 4u control registers. (includes address space definitions
 * and some registers in control space).
 */

/*
 * The Alternate address spaces. 
 * 
 * 0x00-0x7f are privileged 
 * 0x80-0xff can be used by users
 */

#define	ASI_LITTLE	0x08		/* This bit should make an ASI little endian */

#define	ASI_NUCLEUS			0x04	/* [4u] kernel address space */
#define	ASI_NUCLEUS_LITTLE		0x0c	/* [4u] kernel address space, little endian */

#define	ASI_AS_IF_USER_PRIMARY		0x10	/* [4u] primary user address space */
#define	ASI_AS_IF_USER_SECONDARY	0x11	/* [4u] secondary user address space */

#define	ASI_PHYS_CACHED			0x14	/* [4u] MMU bypass to main memory */
#define	ASI_PHYS_NON_CACHED		0x15	/* [4u] MMU bypass to I/O location */

#define	ASI_AS_IF_USER_PRIMARY_LITTLE	0x18	/* [4u] primary user address space, little endian  */
#define	ASI_AS_IF_USER_SECONDARY_LITTLE	0x19	/* [4u] secondary user address space, little endian  */

#define	ASI_PHYS_CACHED_LITTLE		0x1c	/* [4u] MMU bypass to main memory, little endian */
#define	ASI_PHYS_NON_CACHED_LITTLE	0x1d	/* [4u] MMU bypass to I/O location, little endian */

#define ASI_MMU_CONTEXTID		0x21	/* [4v] MMU context control - both IMMU and DMMU */

#define	ASI_NUCLEUS_QUAD_LDD		0x24	/* [4u] use w/LDDA to load 128-bit item */
#define	ASI_QUEUE			0x25	/* [4v] interrupt queue registers */
#define	ASI_NUCLEUS_QUAD_LDD_LITTLE	0x2c	/* [4u] use w/LDDA to load 128-bit item, little endian */

#define	ASI_FLUSH_D_PAGE_PRIMARY	0x38	/* [4u] flush D-cache page using primary context */
#define	ASI_FLUSH_D_PAGE_SECONDARY	0x39	/* [4u] flush D-cache page using secondary context */
#define	ASI_FLUSH_D_CTX_PRIMARY		0x3a	/* [4u] flush D-cache context using primary context */
#define	ASI_FLUSH_D_CTX_SECONDARY	0x3b	/* [4u] flush D-cache context using secondary context */

#define	ASI_DCACHE_INVALIDATE		0x42	/* [III] invalidate D-cache */
#define	ASI_DCACHE_UTAG			0x43	/* [III] diagnostic access to D-cache micro tag */
#define	ASI_DCACHE_SNOOP_TAG		0x44	/* [III] diagnostic access to D-cache snoop tag RAM */

#define	ASI_LSU_CONTROL_REGISTER	0x45	/* [4u] load/store unit control register */

#define	ASI_DCACHE_DATA			0x46	/* [4u] diagnostic access to D-cache data RAM */
#define	ASI_DCACHE_TAG			0x47	/* [4u] diagnostic access to D-cache tag RAM */

#define	ASI_INTR_DISPATCH_STATUS	0x48	/* [4u] interrupt dispatch status register */
#define	ASI_INTR_RECEIVE		0x49	/* [4u] interrupt receive status register */
#define	ASI_MID_REG			0x4a	/* [4u] hardware config and MID */
#define	ASI_ERROR_EN_REG		0x4b	/* [4u] asynchronous error enables */
#define	ASI_AFSR			0x4c	/* [4u] asynchronous fault status register */
#define	ASI_AFAR			0x4d	/* [4u] asynchronous fault address register */

#define	ASI_ICACHE_DATA			0x66	/* [4u] diagnostic access to I-cache data RAM */
#define	ASI_ICACHE_TAG			0x67	/* [4u] diagnostic access to I-cache tag RAM */
#define	ASI_FLUSH_I_PAGE_PRIMARY	0x68	/* [4u] flush I-cache page using primary context */
#define	ASI_FLUSH_I_PAGE_SECONDARY	0x69	/* [4u] flush I-cache page using secondary context */
#define	ASI_FLUSH_I_CTX_PRIMARY		0x6a	/* [4u] flush I-cache context using primary context */
#define	ASI_FLUSH_I_CTX_SECONDARY	0x6b	/* [4u] flush I-cache context using secondary context */

#define	ASI_BLOCK_AS_IF_USER_PRIMARY	0x70	/* [4u] primary user address space, block loads/stores */
#define	ASI_BLOCK_AS_IF_USER_SECONDARY	0x71	/* [4u] secondary user address space, block loads/stores */

#define	ASI_ECACHE_DIAG			0x76	/* [4u] diag access to E-cache tag and data */
#define	ASI_DATAPATH_ERR_REG_WRITE	0x77	/* [4u] ASI is reused */

#define	ASI_BLOCK_AS_IF_USER_PRIMARY_LITTLE	0x78	/* [4u] primary user address space, block loads/stores */
#define	ASI_BLOCK_AS_IF_USER_SECONDARY_LITTLE	0x79	/* [4u] secondary user address space, block loads/stores */

#define	ASI_INTERRUPT_RECEIVE_DATA	0x7f	/* [4u] interrupt receive data registers {0,1,2} */
#define	ASI_DATAPATH_ERR_REG_READ	0x7f	/* [4u] read access to datapath error registers (ASI reused) */

#define	ASI_PRIMARY			0x80	/* [4u] primary address space */
#define	ASI_SECONDARY			0x81	/* [4u] secondary address space */
#define	ASI_PRIMARY_NOFAULT		0x82	/* [4u] primary address space, no fault */
#define	ASI_SECONDARY_NOFAULT		0x83	/* [4u] secondary address space, no fault */

#define	ASI_PRIMARY_LITTLE		0x88	/* [4u] primary address space, little endian */
#define	ASI_SECONDARY_LITTLE		0x89	/* [4u] secondary address space, little endian */
#define	ASI_PRIMARY_NOFAULT_LITTLE	0x8a	/* [4u] primary address space, no fault, little endian */
#define	ASI_SECONDARY_NOFAULT_LITTLE	0x8b	/* [4u] secondary address space, no fault, little endian */

#define	ASI_PST8_PRIMARY		0xc0	/* [VIS] Eight 8-bit partial store, primary */
#define	ASI_PST8_SECONDARY		0xc1	/* [VIS] Eight 8-bit partial store, secondary */
#define	ASI_PST16_PRIMARY		0xc2	/* [VIS] Four 16-bit partial store, primary */
#define	ASI_PST16_SECONDARY		0xc3	/* [VIS] Fout 16-bit partial store, secondary */
#define	ASI_PST32_PRIMARY		0xc4	/* [VIS] Two 32-bit partial store, primary */
#define	ASI_PST32_SECONDARY		0xc5	/* [VIS] Two 32-bit partial store, secondary */

#define	ASI_PST8_PRIMARY_LITTLE		0xc8	/* [VIS] Eight 8-bit partial store, primary, little endian */
#define	ASI_PST8_SECONDARY_LITTLE	0xc9	/* [VIS] Eight 8-bit partial store, secondary, little endian */
#define	ASI_PST16_PRIMARY_LITTLE	0xca	/* [VIS] Four 16-bit partial store, primary, little endian */
#define	ASI_PST16_SECONDARY_LITTLE	0xcb	/* [VIS] Fout 16-bit partial store, secondary, little endian */
#define	ASI_PST32_PRIMARY_LITTLE	0xcc	/* [VIS] Two 32-bit partial store, primary, little endian */
#define	ASI_PST32_SECONDARY_LITTLE	0xcd	/* [VIS] Two 32-bit partial store, secondary, little endian */

#define	ASI_FL8_PRIMARY			0xd0	/* [VIS] One 8-bit load/store floating, primary */
#define	ASI_FL8_SECONDARY		0xd1	/* [VIS] One 8-bit load/store floating, secondary */
#define	ASI_FL16_PRIMARY		0xd2	/* [VIS] One 16-bit load/store floating, primary */
#define	ASI_FL16_SECONDARY		0xd3	/* [VIS] One 16-bit load/store floating, secondary */

#define	ASI_FL8_PRIMARY_LITTLE		0xd8	/* [VIS] One 8-bit load/store floating, primary, little endian */
#define	ASI_FL8_SECONDARY_LITTLE	0xd9	/* [VIS] One 8-bit load/store floating, secondary, little endian */
#define	ASI_FL16_PRIMARY_LITTLE		0xda	/* [VIS] One 16-bit load/store floating, primary, little endian */
#define	ASI_FL16_SECONDARY_LITTLE	0xdb	/* [VIS] One 16-bit load/store floating, secondary, little endian */

#define	ASI_BLOCK_COMMIT_PRIMARY	0xe0	/* [4u] block store with commit, primary */
#define	ASI_BLOCK_COMMIT_SECONDARY	0xe1	/* [4u] block store with commit, secondary */
#define	ASI_BLOCK_PRIMARY		0xf0	/* [4u] block load/store, primary */
#define	ASI_BLOCK_SECONDARY		0xf1	/* [4u] block load/store, secondary */
#define	ASI_BLOCK_PRIMARY_LITTLE	0xf8	/* [4u] block load/store, primary, little endian */
#define	ASI_BLOCK_SECONDARY_LITTLE	0xf9	/* [4u] block load/store, secondary, little endian */


/*
 * These are the shorter names used by Solaris
 */

#define	ASI_N		ASI_NUCLEUS
#define	ASI_NL		ASI_NUCLEUS_LITTLE
#define	ASI_AIUP	ASI_AS_IF_USER_PRIMARY
#define	ASI_AIUS	ASI_AS_IF_USER_SECONDARY
#define	ASI_AIUPL	ASI_AS_IF_USER_PRIMARY_LITTLE
#define	ASI_AIUSL	ASI_AS_IF_USER_SECONDARY_LITTLE
#define	ASI_P		ASI_PRIMARY
#define	ASI_S		ASI_SECONDARY
#define	ASI_PNF		ASI_PRIMARY_NOFAULT
#define	ASI_SNF		ASI_SECONDARY_NOFAULT
#define	ASI_PL		ASI_PRIMARY_LITTLE
#define	ASI_SL		ASI_SECONDARY_LITTLE
#define	ASI_PNFL	ASI_PRIMARY_NOFAULT_LITTLE
#define	ASI_SNFL	ASI_SECONDARY_NOFAULT_LITTLE
#define	ASI_FL8_P	ASI_FL8_PRIMARY
#define	ASI_FL8_S	ASI_FL8_SECONDARY
#define	ASI_FL16_P	ASI_FL16_PRIMARY
#define	ASI_FL16_S	ASI_FL16_SECONDARY
#define	ASI_FL8_PL	ASI_FL8_PRIMARY_LITTLE
#define	ASI_FL8_SL	ASI_FL8_SECONDARY_LITTLE
#define	ASI_FL16_PL	ASI_FL16_PRIMARY_LITTLE
#define	ASI_FL16_SL	ASI_FL16_SECONDARY_LITTLE
#define	ASI_BLK_AIUP	ASI_BLOCK_AS_IF_USER_PRIMARY
#define	ASI_BLK_AIUPL	ASI_BLOCK_AS_IF_USER_PRIMARY_LITTLE
#define	ASI_BLK_AIUS	ASI_BLOCK_AS_IF_USER_SECONDARY
#define	ASI_BLK_AIUSL	ASI_BLOCK_AS_IF_USER_SECONDARY_LITTLE
#define	ASI_BLK_COMMIT_P		ASI_BLOCK_COMMIT_PRIMARY
#define	ASI_BLK_COMMIT_PRIMARY		ASI_BLOCK_COMMIT_PRIMARY
#define	ASI_BLK_COMMIT_S		ASI_BLOCK_COMMIT_SECONDARY
#define	ASI_BLK_COMMIT_SECONDARY	ASI_BLOCK_COMMIT_SECONDARY
#define	ASI_BLK_P			ASI_BLOCK_PRIMARY
#define	ASI_BLK_PL			ASI_BLOCK_PRIMARY_LITTLE
#define	ASI_BLK_S			ASI_BLOCK_SECONDARY
#define	ASI_BLK_SL			ASI_BLOCK_SECONDARY_LITTLE

/* Alternative spellings */
#define ASI_PRIMARY_NO_FAULT		ASI_PRIMARY_NOFAULT
#define ASI_PRIMARY_NO_FAULT_LITTLE	ASI_PRIMARY_NOFAULT_LITTLE
#define ASI_SECONDARY_NO_FAULT		ASI_SECONDARY_NOFAULT
#define ASI_SECONDARY_NO_FAULT_LITTLE	ASI_SECONDARY_NOFAULT_LITTLE

#define	PHYS_ASI(x)	(((x) | 0x09) == 0x1d)
#define	LITTLE_ASI(x)	((x) & ASI_LITTLE)

/* 
 * The following are 4u control registers
 */

/* Get the CPU's UPAID */
#define	UPA_CR_MID_SHIFT	(17)
#define	UPA_CR_MID_SIZE		(5)
#define	UPA_CR_MID_MASK \
	(((1 << UPA_CR_MID_SIZE) - 1) << UPA_CR_MID_SHIFT)

#define	UPA_CR_MID(x)	(((x)>>UPA_CR_MID_SHIFT)&((1 << UPA_CR_MID_SIZE) - 1))	

#ifdef _LOCORE

#define	UPA_GET_MID(r1) \
	ldxa	[%g0] ASI_MID_REG, r1 ; \
	srlx	r1, UPA_CR_MID_SHIFT, r1 ; \
	and	r1, (1 << UPA_CR_MID_SIZE) - 1, r1

#else
#define	CPU_UPAID	UPA_CR_MID(ldxa(0, ASI_MID_REG))
#endif
  
/* Get the CPU's Fireplane agent ID */
#define FIREPLANE_CR_AID(x)	(((x) >> 17) & 0x3ff)
#define CPU_FIREPLANEID		FIREPLANE_CR_AID(ldxa(0, ASI_MID_REG))

/* Get the CPU's Jupiter Bus interrupt target ID */
#define JUPITER_CR_ITID(x)	((x) & 0x3ff)
#define CPU_JUPITERID		JUPITER_CR_ITID(ldxa(0, ASI_MID_REG))

/*
 * [4u] MMU and Cache Control Register (MCCR)
 * use ASI = 0x45
 */
#define	ASI_MCCR	ASI_LSU_CONTROL_REGISTER
#define	MCCR		0x00

/* MCCR Bits and their meanings */
#define	MCCR_DMMU_EN	0x08
#define	MCCR_IMMU_EN	0x04
#define	MCCR_DCACHE_EN	0x02
#define	MCCR_ICACHE_EN	0x01
#define	MCCR_RAW_EN	0x400000000000


/*
 * MMU control registers
 */

/* Choose an MMU */
#define	ASI_DMMU		0x58
#define	ASI_IMMU		0x50

/* Other assorted MMU ASIs */
#define	ASI_IMMU_8KPTR		0x51
#define	ASI_IMMU_64KPTR		0x52
#define	ASI_IMMU_DATA_IN	0x54
#define	ASI_IMMU_TLB_DATA	0x55
#define	ASI_IMMU_TLB_TAG	0x56
#define	ASI_DMMU_8KPTR		0x59
#define	ASI_DMMU_64KPTR		0x5a
#define	ASI_DMMU_DATA_IN	0x5c
#define	ASI_DMMU_TLB_DATA	0x5d
#define	ASI_DMMU_TLB_TAG	0x5e

/* 
 * The following are the control registers 
 * They work on both MMUs unless noted.
 * III = cheetah only
 *
 * Register contents are defined later on individual registers.
 */
#define	TSB_TAG_TARGET		0x0
#define	TLB_DATA_IN		0x0
#define	CTX_PRIMARY		0x08	/* primary context -- DMMU only */
#define	CTX_SECONDARY		0x10	/* secondary context -- DMMU only */
#define	SFSR			0x18
#define	SFAR			0x20	/* fault address -- DMMU only */
#define	TSB			0x28
#define	TLB_TAG_ACCESS		0x30
#define	VIRTUAL_WATCHPOINT	0x38
#define	PHYSICAL_WATCHPOINT	0x40
#define	TSB_PEXT		0x48	/* III primary ext */
#define	TSB_SEXT		0x50	/* III 2ndary ext -- DMMU only */
#define	TSB_NEXT		0x58	/* III nucleus ext */

/* Tag Target bits */
#define	TAG_TARGET_VA_MASK	0x03ffffffffffffffffLL
#define	TAG_TARGET_VA(x)	(((x)<<22)&TAG_TARGET_VA_MASK)
#define	TAG_TARGET_CONTEXT(x)	((x)>>48)
#define	TAG_TARGET(c,v)		((((uint64_t)c)<<48)|(((uint64_t)v)&TAG_TARGET_VA_MASK))

/* SFSR bits for both D_SFSR and I_SFSR */
#define	SFSR_ASI(x)		((x)>>16)
#define	SFSR_FT_VA_OOR_2	0x02000 /* IMMU: jumpl or return to unsupportd VA */
#define	SFSR_FT_VA_OOR_1	0x01000 /* fault at unsupported VA */
#define	SFSR_FT_NFO		0x00800	/* DMMU: Access to page marked NFO */
#define	SFSR_ILL_ASI		0x00400	/* DMMU: Illegal (unsupported) ASI */
#define	SFSR_FT_IO_ATOMIC	0x00200	/* DMMU: Atomic access to noncacheable page */
#define	SFSR_FT_ILL_NF		0x00100	/* DMMU: NF load or flush to page marked E (has side effects) */
#define	SFSR_FT_PRIV		0x00080	/* Privilege violation */
#define	SFSR_FT_E		0x00040	/* DMUU: value of E bit associated address */
#define	SFSR_CTXT(x)		(((x)>>4)&0x3)
#define	SFSR_CTXT_IS_PRIM(x)	(SFSR_CTXT(x)==0x00)
#define	SFSR_CTXT_IS_SECOND(x)	(SFSR_CTXT(x)==0x01)
#define	SFSR_CTXT_IS_NUCLEUS(x)	(SFSR_CTXT(x)==0x02)
#define	SFSR_PRIV		0x00008	/* value of PSTATE.PRIV for faulting access */
#define	SFSR_W			0x00004 /* DMMU: attempted write */
#define	SFSR_OW			0x00002 /* Overwrite; prev vault was still valid */
#define	SFSR_FV			0x00001	/* Fault is valid */
#define	SFSR_FT	(SFSR_FT_VA_OOR_2|SFSR_FT_VA_OOR_1|SFSR_FT_NFO| \
		SFSR_ILL_ASI|SFSR_FT_IO_ATOMIC|SFSR_FT_ILL_NF|SFSR_FT_PRIV)

#define	SFSR_BITS "\177\20" \
	"f\20\30ASI\0" "b\16VAT\0" "b\15VAD\0" "b\14NFO\0" "b\13ASI\0" "b\12A\0" \
	"b\11NF\0" "b\10PRIV\0" "b\7E\0" "b\6NUCLEUS\0" "b\5SECONDCTX\0" "b\4PRIV\0" \
	"b\3W\0" "b\2OW\0" "b\1FV\0"

/* ASFR bits */
#define	ASFR_ME			0x100000000LL
#define	ASFR_PRIV		0x080000000LL
#define	ASFR_ISAP		0x040000000LL
#define	ASFR_ETP		0x020000000LL
#define	ASFR_IVUE		0x010000000LL
#define	ASFR_TO			0x008000000LL
#define	ASFR_BERR		0x004000000LL
#define	ASFR_LDP		0x002000000LL
#define	ASFR_CP			0x001000000LL
#define	ASFR_WP			0x000800000LL
#define	ASFR_EDP		0x000400000LL
#define	ASFR_UE			0x000200000LL
#define	ASFR_CE			0x000100000LL
#define	ASFR_ETS		0x0000f0000LL
#define	ASFT_P_SYND		0x00000ffffLL

#define	AFSR_BITS "\177\20" \
        "b\40ME\0"      "b\37PRIV\0"    "b\36ISAP\0"    "b\35ETP\0" \
        "b\34IVUE\0"    "b\33TO\0"      "b\32BERR\0"    "b\31LDP\0" \
        "b\30CP\0"      "b\27WP\0"      "b\26EDP\0"     "b\25UE\0" \
        "b\24CE\0"      "f\20\4ETS\0"   "f\0\20P_SYND\0"

/*  
 * Here's the spitfire TSB control register bits.
 * 
 * Each TSB entry is 16-bytes wide.  The TSB must be size aligned
 */
#define	TSB_SIZE_512		0x0	/* 8kB, etc. */	
#define	TSB_SIZE_1K		0x01
#define	TSB_SIZE_2K		0x02	
#define	TSB_SIZE_4K		0x03	
#define	TSB_SIZE_8K		0x04
#define	TSB_SIZE_16K		0x05
#define	TSB_SIZE_32K		0x06
#define	TSB_SIZE_64K		0x07
#define	TSB_SPLIT		0x1000
#define	TSB_BASE		0xffffffffffffe000

/*  TLB Tag Access bits */
#define	TLB_TAG_ACCESS_VA	0xffffffffffffe000
#define	TLB_TAG_ACCESS_CTX	0x0000000000001fff

/*
 * TLB demap registers.  TTEs are defined in v9pte.h
 *
 * Use the address space to select between IMMU and DMMU.
 * The address of the register selects which context register
 * to read the ASI from.  
 *
 * The data stored in the register is interpreted as the VA to
 * use.  The DEMAP_CTX_<> registers ignore the address and demap the
 * entire ASI.
 * 
 */
#define	ASI_IMMU_DEMAP			0x57	/* [4u] IMMU TLB demap */
#define	ASI_DMMU_DEMAP			0x5f	/* [4u] IMMU TLB demap */

#define	DEMAP_PAGE_NUCLEUS		((0x02)<<4)	/* Demap page from kernel AS */
#define	DEMAP_PAGE_PRIMARY		((0x00)<<4)	/* Demap a page from primary CTXT */
#define	DEMAP_PAGE_SECONDARY		((0x01)<<4)	/* Demap page from secondary CTXT (DMMU only) */
#define	DEMAP_CTX_NUCLEUS		((0x06)<<4)	/* Demap all of kernel CTXT */
#define	DEMAP_CTX_PRIMARY		((0x04)<<4)	/* Demap all of primary CTXT */
#define	DEMAP_CTX_SECONDARY		((0x05)<<4)	/* Demap all of secondary CTXT */
#define	DEMAP_ALL			((0x08)<<4)	/* Demap all non-locked TLB entries [USIII] */

/*
 * These define the sizes of the TLB in various CPUs.
 * They're mostly not necessary except for diagnostic code.
 */
#define TLB_SIZE_SPITFIRE		64
#define TLB_SIZE_CHEETAH_I16		16
#define TLB_SIZE_CHEETAH_I128		128
#define TLB_SIZE_CHEETAH_D16		16
#define TLB_SIZE_CHEETAH_D512_0		512
#define TLB_SIZE_CHEETAH_D512_1		512
#define TLB_CHEETAH_I16			(0 << 16)
#define TLB_CHEETAH_I128		(2 << 16)
#define TLB_CHEETAH_D16			(0 << 16)
#define TLB_CHEETAH_D512_0		(2 << 16)
#define TLB_CHEETAH_D512_1		(3 << 16)

/*
 * Interrupt registers.  This really gets hairy.
 */

/* IRSR -- Interrupt Receive Status Ragister */
#define	ASI_IRSR	0x49
#define	IRSR		0x00
#define	IRSR_BUSY	0x020
#define	IRSR_MID(x)	(x&0x1f)

/* IRDR -- Interrupt Receive Data Registers */
#define	ASI_IRDR	0x7f
#define	IRDR_0H		0x40
#define	IRDR_0L		0x48	/* unimplemented */
#define	IRDR_1H		0x50
#define	IRDR_1L		0x58	/* unimplemented */
#define	IRDR_2H		0x60
#define	IRDR_2L		0x68	/* unimplemented */
#define	IRDR_3H		0x70	/* unimplemented */
#define	IRDR_3L		0x78	/* unimplemented */

/* Interrupt Dispatch -- usually reserved for cross-calls */
#define	ASI_IDSR	0x48 /* Interrupt dispatch status reg */
#define	IDSR		0x00
#define	IDSR_NACK	0x02
#define	IDSR_BUSY	0x01

#define	ASI_INTERRUPT_DISPATCH		0x77	/* [4u] spitfire interrupt dispatch regs */

/* Interrupt delivery initiation */
#define	IDCR(x)		((((uint64_t)(x)) << 14) | 0x70)

#define	IDDR_0H		0x40	/* Store data to send in these regs */
#define	IDDR_0L		0x48	/* unimplemented */
#define	IDDR_1H		0x50
#define	IDDR_1L		0x58	/* unimplemented */
#define	IDDR_2H		0x60
#define	IDDR_2L		0x68	/* unimplemented */
#define	IDDR_3H		0x70	/* unimplemented */
#define	IDDR_3L		0x78	/* unimplemented */

/*
 * Error registers 
 */

/* Since we won't try to fix async errs, we don't care about the bits in the regs */
#define	ASI_AFAR	0x4d	/* Asynchronous fault address register */
#define	AFAR		0x00
#define	ASI_AFSR	0x4c	/* Asynchronous fault status register */
#define	AFSR		0x00

#define	ASI_P_EER	0x4b	/* Error enable register */
#define	P_EER		0x00
#define	P_EER_ISAPEN	0x04	/* Enable fatal on ISAP */
#define	P_EER_NCEEN	0x02	/* Enable trap on uncorrectable errs */
#define	P_EER_CEEN	0x01	/* Enable trap on correctable errs */

#define	ASI_DATAPATH_READ	0x7f /* Read the regs */
#define	ASI_DATAPATH_WRITE	0x77 /* Write to the regs */
#define	P_DPER_0	0x00	/* Datapath err reg 0 */
#define	P_DPER_1	0x18	/* Datapath err reg 1 */
#define	P_DCR_0		0x20	/* Datapath control reg 0 */
#define	P_DCR_1		0x38	/* Datapath control reg 0 */


/* From sparc64/asm.h which I think I'll deprecate since it makes bus.h a pain. */

#ifndef _LOCORE
/*
 * GCC __asm constructs for doing assembly stuff.
 */

/*
 * ``Routines'' to load and store from/to alternate address space.
 * The location can be a variable, the asi value (address space indicator)
 * must be a constant.
 *
 * N.B.: You can put as many special functions here as you like, since
 * they cost no kernel space or time if they are not used.
 *
 * These were static inline functions, but gcc screws up the constraints
 * on the address space identifiers (the "n"umeric value part) because
 * it inlines too late, so we have to use the funny valued-macro syntax.
 */

/* 
 * Apparently the definition of bypass ASIs is that they all use the 
 * D$ so we need to flush the D$ to make sure we don't get data pollution.
 */

#ifdef __arch64__

/* 64-bit kernel, non-constant */
#define SPARC64_LD_NONCONST(ld)	\
	__asm volatile(							\
		"wr %2,%%g0,%%asi;	"				\
		#ld " [%1]%%asi,%0	"				\
		: "=r" (_v)						\
		: "r" ((__uintptr_t)(loc)), "r" (asi))

#if defined(__GNUC__) && defined(__OPTIMIZE__)
#define SPARC64_LD_DEF(ld, type, vtype)	\
static __inline type ld(paddr_t loc, int asi)				\
{									\
	vtype _v;							\
	if (__builtin_constant_p(asi))					\
		__asm volatile(						\
			#ld " [%1]%2,%0		"			\
			: "=r" (_v)					\
			: "r" ((__uintptr_t)(loc)), "n" (asi));		\
	else								\
		SPARC64_LD_NONCONST(ld);				\
	return _v;							\
}
#else
#define SPARC64_LD_DEF(ld, type, vtype)	\
static __inline type ld(paddr_t loc, int asi)				\
{									\
	vtype _v;							\
	SPARC64_LD_NONCONST(ld);					\
	return _v;							\
}
#endif
#define SPARC64_LD_DEF64(ld, type)	SPARC64_LD_DEF(ld, type, uint64_t)

#else	/* __arch64__ */

/* 32-bit kernel, MMU bypass, non-constant */
#define SPARC64_LD_PHYS_NONCONST(ld)	\
	__asm volatile(							\
		"clruw %2;		"				\
		"rdpr %%pstate,%1;	"				\
		"sllx %3,32,%0;		"				\
		"wrpr %1,8,%%pstate;	"				\
		"or %0,%2,%0;		"				\
		"wr %4,%%g0,%%asi;	"				\
		#ld " [%0]%%asi,%0;	"				\
		"wrpr %1,0,%%pstate	"				\
		: "=&r" (_v),  "=&r" (_pstate)				\
		: "r" ((uint32_t)(loc)), "r" (_hi), "r" (asi))
/* 32-bit kernel, non-constant */
#define SPARC64_LD_NONCONST(ld)	\
	__asm volatile(							\
		"wr %2,%%g0,%%asi;	"				\
		#ld " [%1]%%asi,%0	"				\
		: "=&r" (_v)						\
		: "r" ((uint32_t)(loc)), "r" (asi))
/* 32-bit kernel, MMU bypass, non-constant, 64-bit value */
#define SPARC64_LD_PHYS_NONCONST64(ld)	\
	__asm volatile(							\
		"clruw %2;		"				\
		"rdpr %%pstate,%1;	"				\
		"sllx %3,32,%0;		"				\
		"wrpr %1,8,%%pstate;	"				\
		"or %0,%2,%0;		"				\
		"wr %4,%%g0,%%asi;	"				\
		#ld " [%0]%%asi,%0;	"				\
		"wrpr %1,0,%%pstate;	"				\
		"srlx %0,32,%1;		"				\
		"srl %0,0,%0		"				\
		: "=&r" (_vlo), "=&r" (_vhi)				\
		: "r" ((uint32_t)(loc)), "r" (_hi), "r" (asi))
/* 32-bit kernel, non-constant, 64-bit value  */
#define SPARC64_LD_NONCONST64(ld)	\
	__asm volatile(							\
		"wr %3,%%g0,%%asi;	"				\
		#ld " [%2]%%asi,%0;	"				\
		"srlx %0,32,%1;		"				\
		"srl %0,0,%0		"				\
		: "=&r" (_vlo), "=&r" (_vhi)				\
		: "r" ((uint32_t)(loc)), "r" (asi))

#if defined(__GNUC__) && defined(__OPTIMIZE__)
#define SPARC64_LD_DEF(ld, type, vtype)	\
static __inline type ld(paddr_t loc, int asi)				\
{									\
	vtype _v;							\
	uint32_t _hi, _pstate;						\
	if (PHYS_ASI(asi)) {						\
		_hi = (uint64_t)(loc) >> 32;				\
		if (__builtin_constant_p(asi))				\
			__asm volatile(					\
				"clruw %2;		"		\
				"rdpr %%pstate,%1;	"		\
				"sllx %3,32,%0;		"		\
				"wrpr %1,8,%%pstate;	"		\
				"or %0,%2,%0;		"		\
				#ld " [%0]%4,%0;	"		\
				"wrpr %1,0,%%pstate;	"		\
				: "=&r" (_v),  "=&r" (_pstate)		\
				: "r" ((uint32_t)(loc)), "r" (_hi),	\
				  "n" (asi));				\
		else							\
			SPARC64_LD_PHYS_NONCONST(ld);			\
	} else {							\
		if (__builtin_constant_p(asi))				\
			__asm volatile(					\
				#ld " [%1]%2,%0		"		\
				: "=&r" (_v)				\
				: "r" ((uint32_t)(loc)), "n" (asi));	\
		else							\
			SPARC64_LD_NONCONST(ld);			\
	}								\
	return _v;							\
}
#define SPARC64_LD_DEF64(ld, type)	\
static __inline type ld(paddr_t loc, int asi)				\
{									\
	uint32_t _vlo, _vhi, _hi;					\
	if (PHYS_ASI(asi)) {						\
		_hi = (uint64_t)(loc) >> 32;				\
		if (__builtin_constant_p(asi))				\
			__asm volatile(					\
				"clruw %2;		"		\
				"rdpr %%pstate,%1;	"		\
				"sllx %3,32,%0;		"		\
				"wrpr %1,8,%%pstate;	"		\
				"or %0,%2,%0;		"		\
				#ld " [%0]%4,%0;	"		\
				"wrpr %1,0,%%pstate;	"		\
				"srlx %0,32,%1;		"		\
				"srl %0,0,%0		"		\
				: "=&r" (_vlo),  "=&r" (_vhi)		\
				: "r" ((uint32_t)(loc)), "r" (_hi),	\
				  "n" (asi));				\
		else							\
			SPARC64_LD_PHYS_NONCONST64(ld);			\
	} else {							\
		if (__builtin_constant_p(asi))				\
			__asm volatile(					\
				#ld " [%2]%3,%0;	"		\
				"srlx %0,32,%1;		"		\
				"srl %0,0,%0		"		\
				: "=&r" (_vlo),  "=&r" (_vhi)		\
				: "r" ((uint32_t)(loc)), "n" (asi));	\
		else							\
			SPARC64_LD_NONCONST64(ld);			\
	}								\
	return ((uint64_t)_vhi << 32) | _vlo;				\
}
#else
#define SPARC64_LD_DEF(ld, type, vtype)	\
static __inline type ld(paddr_t loc, int asi)				\
{									\
	vtype _v;							\
	uint32_t _hi, _pstate;						\
	if (PHYS_ASI(asi)) {						\
		_hi = (uint64_t)(loc) >> 32;				\
		SPARC64_LD_PHYS_NONCONST(ld);				\
	} else								\
		SPARC64_LD_NONCONST(ld);				\
	return _v;							\
}
#define SPARC64_LD_DEF64(ld, type)	\
static __inline type ld(paddr_t loc, int asi)				\
{									\
	uint32_t _vlo, _vhi, _hi;					\
	if (PHYS_ASI(asi)) {						\
		_hi = (uint64_t)(loc) >> 32;				\
		SPARC64_LD_PHYS_NONCONST64(ld);				\
	} else								\
		SPARC64_LD_NONCONST64(ld);				\
	return ((uint64_t)_vhi << 32) | _vlo;				\
}
#endif

#endif	/* __arch64__ */

/* load byte from alternate address space */
SPARC64_LD_DEF(lduba, uint8_t, uint32_t)
/* load half-word from alternate address space */
SPARC64_LD_DEF(lduha, uint16_t, uint32_t)
/* load unsigned int from alternate address space */
SPARC64_LD_DEF(lda, uint32_t, uint32_t)
/* load unsigned word from alternate address space */
SPARC64_LD_DEF(lduwa, uint32_t, uint32_t)
/* load signed int from alternate address space */
SPARC64_LD_DEF(ldswa, int, int)
/* load 64-bit unsigned int from alternate address space */
SPARC64_LD_DEF64(ldxa, uint64_t)


#ifdef __arch64__

/* 64-bit kernel, non-constant */
#define SPARC64_ST_NONCONST(st)	\
	__asm volatile(							\
		"wr %2,%%g0,%%asi;	"				\
		#st " %0,[%1]%%asi	"				\
		: : "r" (value), "r" ((__uintptr_t)(loc)),		\
		    "r" (asi))

#if defined(__GNUC__) && defined(__OPTIMIZE__)
#define SPARC64_ST_DEF(st, type)	\
static __inline void st(paddr_t loc, int asi, type value)		\
{									\
	if (__builtin_constant_p(asi))					\
		__asm volatile(						\
			#st " %0,[%1]%2		"			\
			: : "r" (value), "r" ((__uintptr_t)(loc)),	\
			    "n" (asi));					\
	else								\
		SPARC64_ST_NONCONST(st);				\
}
#else
#define SPARC64_ST_DEF(st, type)	\
static __inline void st(paddr_t loc, int asi, type value)		\
{									\
	SPARC64_ST_NONCONST(st);					\
}
#endif
#define SPARC64_ST_DEF64(st, type)	SPARC64_ST_DEF(st, type)

#else	/* __arch64__ */

/* 32-bit kernel, MMU bypass, non-constant */
#define SPARC64_ST_PHYS_NONCONST(st)	\
	__asm volatile(							\
		"clruw %3;		"				\
		"rdpr %%pstate,%1;	"				\
		"sllx %4,32,%0;		"				\
		"wrpr %1,8,%%pstate;	"				\
		"or %0,%3,%0;		"				\
		"wr %5,%%g0,%%asi;	"				\
		#st " %2,[%0]%%asi;	"				\
		"wrpr %1,0,%%pstate	"				\
		: "=&r" (_hi), "=&r" (_pstate)				\
		: "r" (value), "r" ((uint32_t)(loc)),			\
		  "r" (_hi), "r" (asi))
/* 32-bit kernel, non-constant */
#define SPARC64_ST_NONCONST(st)	\
	__asm volatile(							\
		"wr %2,%%g0,%%asi;	"				\
		#st " %0,[%1]%%asi	"				\
		: : "r" (value), "r" ((uint32_t)(loc)), "r" (asi))
/* 32-bit kernel, MMU bypass, non-constant, 64-bit value */
#define SPARC64_ST_PHYS_NONCONST64(st)	\
	__asm volatile(							\
		"clruw %3;		"				\
		"clruw %5;		"				\
		"sllx %4,32,%1;		"				\
		"sllx %6,32,%0; 	"				\
		"rdpr %%pstate,%2;	"				\
		"or %1,%3,%1;		"				\
		"wrpr %2,8,%%pstate;	"				\
		"or %0,%5,%0;		"				\
		"wr %7,%%g0,%%asi;	"				\
		#st " %1,[%0]%%asi;	"				\
		"wrpr %2,0,%%pstate	"				\
		: "=&r" (_hi), "=&r" (_vhi), "=&r" (_vlo)		\
		: "r" (_vlo), "r" (_vhi),				\
		  "r" ((uint32_t)(loc)), "r" (_hi), "r" (asi))
/* 32-bit kernel, non-constant, 64-bit value */
#define SPARC64_ST_NONCONST64(st)	\
	__asm volatile(							\
		"clruw %1;		"				\
		"sllx %2,32,%0;		"				\
		"or %0,%1,%0;		"				\
		"wr %4,%%g0,%%asi;	"				\
		#st " %0,[%3]%%asi	"				\
		: "=&r" (_vhi)						\
		: "r" (_vlo), "r" (_vhi),				\
		  "r" ((uint32_t)(loc)), "r" (asi))

#if defined(__GNUC__) && defined(__OPTIMIZE__)
#define SPARC64_ST_DEF(st, type)	\
static __inline void st(paddr_t loc, int asi, type value)		\
{									\
	uint32_t _hi, _pstate;						\
	if (PHYS_ASI(asi)) {						\
		_hi = (uint64_t)(loc) >> 32;				\
		if (__builtin_constant_p(asi))				\
			__asm volatile(					\
				"clruw %3;		"		\
				"sllx %4,32,%0;		"		\
				"rdpr %%pstate,%1;	"		\
				"or %0,%3,%0;		"		\
				"wrpr %1,8,%%pstate;	"		\
				#st " %2,[%0]%5;	"		\
				"wrpr %1,0,%%pstate	"		\
				: "=&r" (_hi), "=&r" (_pstate)		\
				: "r" (value), "r" ((uint32_t)(loc)),	\
				  "r" (_hi), "n" (asi));		\
		else							\
			SPARC64_ST_PHYS_NONCONST(st);			\
	} else {							\
		if (__builtin_constant_p(asi))				\
			__asm volatile(					\
				#st " %0,[%1]%2		"		\
				: : "r" (value), "r" ((uint32_t)(loc)),	\
				  "n" (asi));				\
		else							\
			SPARC64_ST_NONCONST(st);			\
	}								\
}
#define SPARC64_ST_DEF64(st, type)	\
static __inline void st(paddr_t loc, int asi, type value)		\
{									\
	uint32_t _vlo, _vhi, _hi;					\
	_vlo = value;							\
	_vhi = (uint64_t)(value) >> 32;					\
	if (PHYS_ASI(asi)) {						\
		_hi = (uint64_t)(loc) >> 32;				\
		if (__builtin_constant_p(asi))				\
			__asm volatile(					\
				"clruw %3;		"		\
				"clruw %5;		"		\
				"sllx %4,32,%1;		"		\
				"sllx %6,32,%0; 	"		\
				"rdpr %%pstate,%2;	"		\
				"or %1,%3,%1;		"		\
				"or %0,%5,%0;		"		\
				"wrpr %2,8,%%pstate;	"		\
				#st " %1,[%0]%7;	"		\
				"wrpr %2,0,%%pstate	"		\
				: "=&r" (_hi), "=&r" (_vhi), "=&r" (_vlo) \
				: "r" (_vlo), "r" (_vhi),		\
				  "r" ((uint32_t)(loc)), "r" (_hi),	\
				  "n" (asi));				\
		else							\
			SPARC64_ST_PHYS_NONCONST64(st);			\
	} else {							\
		if (__builtin_constant_p(asi))				\
			__asm volatile(					\
				"clruw %1;		"		\
				"sllx %2,32,%0;		"		\
				"or %0,%1,%0;		"		\
				#st " %0,[%3]%4		"		\
				: "=&r" (_vhi)				\
				: "r" (_vlo), "r" (_vhi),		\
				  "r" ((uint32_t)(loc)), "n" (asi));	\
		else							\
			SPARC64_ST_NONCONST64(st);			\
	}								\
}
#else
#define SPARC64_ST_DEF(st, type)	\
static __inline void st(paddr_t loc, int asi, type value)		\
{									\
	uint32_t _hi, _pstate;						\
	if (PHYS_ASI(asi)) {						\
		_hi = (uint64_t)(loc) >> 32;				\
		SPARC64_ST_PHYS_NONCONST(st);				\
	} else								\
		SPARC64_ST_NONCONST(st);				\
}
#define SPARC64_ST_DEF64(st, type)	\
static __inline void st(paddr_t loc, int asi, type value)		\
{									\
	uint32_t _vlo, _vhi, _hi;					\
	_vlo = value;							\
	_vhi = (uint64_t)(value) >> 32;					\
	if (PHYS_ASI(asi)) {						\
		_hi = (uint64_t)(loc) >> 32;				\
		SPARC64_ST_PHYS_NONCONST64(st);				\
	} else								\
		SPARC64_ST_NONCONST64(st);				\
}
#endif

#endif	/* __arch64__ */

/* store byte to alternate address space */
SPARC64_ST_DEF(stba, uint8_t)
/* store half-word to alternate address space */
SPARC64_ST_DEF(stha, uint16_t)
/* store unsigned int to alternate address space */
SPARC64_ST_DEF(sta, uint32_t)
/* store 64-bit unsigned int to alternate address space */
SPARC64_ST_DEF64(stxa, uint64_t)



/* flush address from cache */
#define	sparc_flush_icache(loc) __asm \
	volatile("flush %0" : : "r" ((__uintptr_t)(loc)))

/*
 * SPARC V9 memory barrier instructions.
 */
/* Make all stores complete before next store */
#define	membar_StoreStore() __asm volatile("membar #StoreStore" : :)
/* Make all loads complete before next store */ 
#define	membar_LoadStore() __asm volatile("membar #LoadStore" : :)
/* Make all stores complete before next load */ 
#define	membar_StoreLoad() __asm volatile("membar #StoreLoad" : :)
/* Make all loads complete before next load */
#define	membar_LoadLoad() __asm volatile("membar #LoadLoad" : :)
/* Complete all outstanding memory operations and exceptions */
#define	membar_Sync() __asm volatile("membar #Sync" : :)
/* Complete all outstanding memory operations */
#define	membar_MemIssue() __asm volatile("membar #MemIssue" : :)
/* Complete all outstanding stores before any new loads */
#define	membar_Lookaside() __asm volatile("membar #Lookaside" : :)

#define membar_Load() __asm volatile("membar #LoadLoad | #LoadStore" : :)
#define membar_Store() __asm volatile("membar #LoadStore | #StoreStore" : :)

#endif

#endif /* _SPARC_CTLREG_H_ */