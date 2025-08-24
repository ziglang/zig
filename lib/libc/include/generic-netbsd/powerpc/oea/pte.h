/*	$NetBSD: pte.h,v 1.10 2020/07/06 08:17:01 rin Exp $	*/

/*-
 * Copyright (C) 2003 Matt Thomas
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

#ifndef	_POWERPC_OEA_PTE_H_
#define	_POWERPC_OEA_PTE_H_

#include <sys/queue.h>

/*
 * Page Table Entries
 */
#ifndef	_LOCORE
#if defined(PMAP_OEA64) || defined(PMAP_OEA64_BRIDGE)
struct pte {
	register64_t pte_hi;
	register64_t pte_lo;
};
#else	/* PMAP_OEA */
struct pte {
	register_t pte_hi;
	register_t pte_lo;
};
#endif

struct pteg {
	struct pte pt[8];
};
#endif	/* _LOCORE */

/* High word: */
#if defined (PMAP_OEA64)
#define	PTE_VALID	0x00000001
#define	PTE_HID		0x00000002
#define	PTE_API		0x00000f80
#define	PTE_API_SHFT	7
#define	PTE_VSID_SHFT	12
#define	PTE_VSID	(~0xfffL)
#elif defined (PMAP_OEA64_BRIDGE)
#define	PTE_VALID	0x00000001
#define	PTE_HID		0x00000002
#define	PTE_API		0x00000f80
#define	PTE_API_SHFT	7
#define	PTE_VSID_SHFT	12
#define	PTE_VSID	(~0xfffULL)
#else
#define	PTE_VALID	0x80000000
#define	PTE_VSID	0x7fffff80
#define	PTE_VSID_SHFT	7
#define	PTE_VSID_LEN	24
#define	PTE_HID		0x00000040
#define	PTE_API		0x0000003f
#define	PTE_API_SHFT	0
#endif	/* PMAP_OEA64 */


/* Low word: */
#if defined (PMAP_OEA64_BRIDGE)
#define	PTE_RPGN	(~0xfffULL)
#else
#define	PTE_RPGN	(~0xfffUL)
#endif
#define	PTE_RPGN_SHFT	12
#define	PTE_REF		0x00000100
#define	PTE_CHG		0x00000080
#define	PTE_W		0x00000040	/* 1 = write-through, 0 = write-back */
#define	PTE_I		0x00000020	/* cache inhibit */
#define	PTE_M		0x00000010	/* memory coherency enable */
#define	PTE_G		0x00000008	/* guarded region (not on 601) */
#define	PTE_WIMG	(PTE_W|PTE_I|PTE_M|PTE_G)
#define	PTE_IG		(PTE_I|PTE_G)
#define	PTE_PP		0x00000003
#define	PTE_SO		0x00000000	/* Super. Only       (U: XX, S: RW) */
#define	PTE_SW		0x00000001	/* Super. Write-Only (U: RO, S: RW) */
#define	PTE_BW		0x00000002	/* Supervisor        (U: RW, S: RW) */
#define	PTE_BR		0x00000003	/* Both Read Only    (U: RO, S: RO) */
#define	PTE_RW		PTE_BW
#define	PTE_RO		PTE_BR

#define	PTE_EXEC	0x00000200	/* pseudo bit; page is exec */

/*
 * Extract bits from address
 */
#define	ADDR_SR	        (~0x0fffffffL)
#define	ADDR_SR_SHFT	28
#define	ADDR_PIDX	0x0ffff000
#define	ADDR_PIDX_SHFT	12
#if defined (PMAP_OEA64) || defined (PMAP_OEA64_BRIDGE)
#define	ADDR_API_SHFT	23	/* API is 5 bits */
#else
#define	ADDR_API_SHFT	22	/* API is 6 bits */
#endif /* PMAP_OEA64 */
#define	ADDR_POFF	0x00000fff

#ifdef PMAP_OEA64
/*
 * Segment Table Element
 */
#ifndef	_LOCORE
struct ste {
	register_t ste_hi;
	register_t ste_lo;
};

struct steg {
	struct ste st[8];
};
#endif	/* _LOCORE */

/* High Word */
#define	STE_VALID	0x00000080
#define	STE_TYPE	0x00000040
#define	STE_SUKEY	0x00000020	/* Super-state protection */
#define	STE_PRKEY	0x00000010	/* User-state protection */
#define	STE_NOEXEC	0x00000008	/* No-execute protection bit */
#define	STE_ESID	(~0x0fffffffL)	/* Effective Segment ID */
#define	STE_ESID_SHFT	28
#define	STE_ESID_MASK	0x0000001f	/* low 5 bits of the ESID */

/* Low Word */
#define	STE_VSID	(~0xfffL)	/* Virtual Segment ID */
#define	STE_VSID_SHFT	12
#define	STE_VSID_WIDTH	52

#define	SR_VSID_SHFT	STE_VSID_SHFT	/* compatibility with PPC_OEA */
#define	SR_VSID_WIDTH	STE_VSID_WIDTH	/* compatibility with PPC_OEA */

#define	SR_KEY_LEN	9		/* 64 groups of 8 segment entries */
#else	/* !defined(PMAP_OEA64) */

/*
 * Segment registers
 */
#define	SR_KEY_LEN	4		/* 16 segment registers */
#define	SR_TYPE		0x80000000	/* T=0 selects memory format */
#define	SR_SUKEY	0x40000000	/* Supervisor protection key */
#define	SR_PRKEY	0x20000000	/* User protection key */
#define	SR_NOEXEC	0x10000000	/* No-execute protection bit */
#define	SR_VSID_SHFT	0		/* Starts at LSB */
#define	SR_VSID_WIDTH	24		/* Goes for 24 bits */

#endif	/* PMAP_OEA64 */

					/* Virtual segment ID */
#define	SR_VSID		(((1L << SR_VSID_WIDTH) - 1) << SR_VSID_SHFT)

#endif	/* _POWERPC_OEA_PTE_H_ */