/*	$NetBSD: mips1_pte.h,v 1.21 2020/07/26 08:08:41 simonb Exp $	*/

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
 *	@(#)pte.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _MIPS_MIPS1_PTE_H_
#define	_MIPS_MIPS1_PTE_H_
/*
 * R2000 hardware page table entry
 */

#ifndef _LOCORE
#if 0
struct mips1_pte {
#if BYTE_ORDER == BIG_ENDIAN
unsigned int	pg_pfnum:20,		/* HW: core page frame number or 0 */
		pg_n:1,			/* HW: non-cacheable bit */
		pg_m:1,			/* HW: dirty bit */
		pg_v:1,			/* HW: valid bit */
		pg_g:1,			/* HW: ignore pid bit */
		:4,
		pg_swapm:1,		/* SW: page must be forced to swap */
		pg_fod:1,		/* SW: is fill on demand (=0) */
		pg_prot:2;		/* SW: access control */
#endif
#if BYTE_ORDER == LITTLE_ENDIAN
unsigned int	pg_prot:2,		/* SW: access control */
		pg_fod:1,		/* SW: is fill on demand (=0) */
		pg_swapm:1,		/* SW: page must be forced to swap */
		:4,
		pg_g:1,			/* HW: ignore pid bit */
		pg_v:1,			/* HW: valid bit */
		pg_m:1,			/* HW: dirty bit */
		pg_n:1,			/* HW: non-cacheable bit */
		pg_pfnum:20;		/* HW: core page frame number or 0 */
#endif
};
#endif
#endif /* _LOCORE */

#define	MIPS1_PG_PROT	0x00000003
#define	MIPS1_PG_RW	0x00000000
#define	MIPS1_PG_RO	0x00000001
#define	MIPS1_PG_WIRED	0x00000002
#define	MIPS1_PG_G	0x00000100
#define	MIPS1_PG_V	0x00000200
#define	MIPS1_PG_NV	0x00000000
#define	MIPS1_PG_D	0x00000400
#define	MIPS1_PG_N	0x00000800
#define	MIPS1_PG_FRAME	0xfffff000
#define	MIPS1_PG_SHIFT	12
#define	MIPS1_PG_PFNUM(x) (((x) & MIPS1_PG_FRAME) >> MIPS1_PG_SHIFT)

#define	MIPS1_PG_ROPAGE	MIPS1_PG_V
#define	MIPS1_PG_RWPAGE	MIPS1_PG_D
#define	MIPS1_PG_CWPAGE	0
#define	MIPS1_PG_RWNCPAGE	(MIPS1_PG_D | MIPS1_PG_N)
#define	MIPS1_PG_CWNCPAGE	MIPS1_PG_N
#define	MIPS1_PG_IOPAGE	(MIPS1_PG_D | MIPS1_PG_N)

#define	mips1_tlbpfn_to_paddr(x)	((x) & MIPS1_PG_FRAME)
#define	mips1_paddr_to_tlbpfn(x)	(x)

#define	MIPS1_PTE_TO_PADDR(pte) ((unsigned)(pte) & MIPS1_PG_FRAME)
#define	MIPS1_PAGE_IS_RDONLY(pte,va) ((int)(pte) & MIPS1_PG_RO)

#endif /* !_MIPS_MIPS1_PTE_H_ */