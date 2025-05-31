/*	$NetBSD: pte_motorola.h,v 1.8.86.1 2024/06/27 19:27:28 martin Exp $	*/

/*
 * Copyright (c) 1988 University of Utah.
 * Copyright (c) 1982, 1986, 1990, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * the Systems Programming Group of the University of Utah Computer
 * Science Department.
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
 * from: Utah $Hdr: pte.h 1.13 92/01/20$
 *
 *	@(#)pte.h	8.1 (Berkeley) 6/10/93
 */

#ifndef	_MACHINE_PTE_H_
#define	_MACHINE_PTE_H_

/*
 * m68k motorola MMU segment/page table entries
 */

typedef u_int	st_entry_t;	/* segment table entry */
typedef u_int	pt_entry_t;	/* page table entry */

#define	PT_ENTRY_NULL	NULL
#define	ST_ENTRY_NULL	NULL

#define PG_SHIFT	PGSHIFT

#define	SG_V		0x00000002	/* segment is valid */
#define	SG_NV		0x00000000
#define	SG_PROT		0x00000004	/* access protection mask */
#define	SG_RO		0x00000004
#define	SG_RW		0x00000000
#define	SG_U		0x00000008	/* modified bit (68040) */
#define	SG_FRAME	((~0U) << PG_SHIFT)
#define	SG_ISHIFT	((PG_SHIFT << 1) - 2)	/* 24 or 22 */
#define	SG_IMASK	((~0U) << SG_ISHIFT)
#define	SG_PSHIFT	PG_SHIFT
#define	SG_PMASK	(((~0U) << SG_PSHIFT) & ~SG_IMASK)

/* 68040 additions */
#define	SG4_MASK1	0xfe000000
#define	SG4_SHIFT1	25
#define	SG4_MASK2	0x01fc0000
#define	SG4_SHIFT2	18
#define	SG4_MASK3	(((~0U) << PG_SHIFT) & ~(SG4_MASK1 | SG4_MASK2))
#define	SG4_SHIFT3	PG_SHIFT
#define	SG4_ADDR1	0xfffffe00
#define	SG4_ADDR2	((~0U) << (20 - PG_SHIFT))
#define	SG4_LEV1SIZE	128
#define	SG4_LEV2SIZE	128
#define	SG4_LEV3SIZE	(1 << (SG4_SHIFT2 - PG_SHIFT))	/* 64 or 32 */

#define	PG_V		0x00000001
#define	PG_NV		0x00000000
#define	PG_PROT		0x00000004
#define	PG_U		0x00000008
#define	PG_M		0x00000010
#define	PG_W		0x00000100
#define	PG_RO		0x00000004
#define	PG_RW		0x00000000
#define	PG_FRAME	((~0U) << PG_SHIFT)
#define	PG_CI		0x00000040
#define	PG_PFNUM(x)	(((x) & PG_FRAME) >> PG_SHIFT)

/* 68040 additions */
#define	PG_CMASK	0x00000060	/* cache mode mask */
#define	PG_CWT		0x00000000	/* writethrough caching */
#define	PG_CCB		0x00000020	/* copyback caching */
#define	PG_CIS		0x00000040	/* cache inhibited serialized */
#define	PG_CIN		0x00000060	/* cache inhibited nonserialized */
#define	PG_SO		0x00000080	/* supervisor only */

#define M68K_STSIZE	(MAXUL2SIZE * SG4_LEV2SIZE * sizeof(st_entry_t))
					/* user process segment table size */
#define M68K_MAX_PTSIZE	(1 << (32 - PG_SHIFT + 2))	/* max size of UPT */
#define M68K_MAX_KPTSIZE	(M68K_MAX_PTSIZE >> 2)	/* max memory to allocate to KPT */
#define M68K_PTBASE	0x10000000	/* UPT map base address */
#define M68K_PTMAXSIZE	0x70000000	/* UPT map maximum size */

/*
 * Kernel virtual address to page table entry and to physical address.
 */

#ifdef cesfic
#define	kvtopte(va) \
	(&Sysmap[((unsigned)(va)) >> PGSHIFT])
#else
#define	kvtopte(va) \
	(&Sysmap[((unsigned)(va) - VM_MIN_KERNEL_ADDRESS) >> PGSHIFT])
#endif

#endif /* !_MACHINE_PTE_H_ */