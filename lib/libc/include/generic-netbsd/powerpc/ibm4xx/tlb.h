/*	$NetBSD: tlb.h,v 1.7 2021/03/30 03:15:53 rin Exp $	*/

/*
 * Copyright 2001 Wasabi Systems, Inc.
 * All rights reserved.
 *
 * Written by Eduardo Horvath and Simon Burge for Wasabi Systems, Inc.
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
 *      This product includes software developed for the NetBSD Project by
 *      Wasabi Systems, Inc.
 * 4. The name of Wasabi Systems, Inc. may not be used to endorse
 *    or promote products derived from this software without specific prior
 *    written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY WASABI SYSTEMS, INC. ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL WASABI SYSTEMS, INC
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _IBM4XX_TLB_H_
#define _IBM4XX_TLB_H_

#define NTLB	64

/* TLBHI entries */
#define TLB_EPN_MASK	0xfffff000 /* It's 0xfffffc00, but as we use 4K pages we don't need two lower bits */
#define TLB_EPN_SHFT	12
#define TLB_SIZE_MASK	0x00000380
#define TLB_SIZE_SHFT	7
#define TLB_VALID	0x00000040
#define TLB_ENDIAN	0x00000020
#define TLB_U0		0x00000010

#define TLB_SIZE_1K	0
#define TLB_SIZE_4K	1
#define TLB_SIZE_16K	2
#define TLB_SIZE_64K	3
#define TLB_SIZE_256K	4
#define TLB_SIZE_1M	5
#define TLB_SIZE_4M	6
#define TLB_SIZE_16M	7

#define	TLB_PG_1K	(TLB_SIZE_1K << TLB_SIZE_SHFT)
#define	TLB_PG_4K	(TLB_SIZE_4K << TLB_SIZE_SHFT)
#define	TLB_PG_16K	(TLB_SIZE_16K << TLB_SIZE_SHFT)
#define	TLB_PG_64K	(TLB_SIZE_64K << TLB_SIZE_SHFT)
#define	TLB_PG_256K	(TLB_SIZE_256K << TLB_SIZE_SHFT)
#define	TLB_PG_1M	(TLB_SIZE_1M << TLB_SIZE_SHFT)
#define	TLB_PG_4M	(TLB_SIZE_4M << TLB_SIZE_SHFT)
#define	TLB_PG_16M	(TLB_SIZE_16M << TLB_SIZE_SHFT)

/* TLBLO entries */
#define TLB_RPN_MASK	0xfffffc00	/* Real Page Number mask */
#define TLB_EX		0x00000200	/* EXecute enable */
#define TLB_WR		0x00000100	/* WRite enable */
#define TLB_ZSEL_MASK	0x000000f0	/* Zone SELect mask */
#define TLB_ZSEL_SHFT	4
#define TLB_W		0x00000008	/* Write-through */
#define TLB_I		0x00000004	/* Inhibit caching */
#define TLB_M		0x00000002	/* Memory coherent */
#define TLB_G		0x00000001	/* Guarded */

#define TLB_ZONE(z)	(((z) << TLB_ZSEL_SHFT) & TLB_ZSEL_MASK)

/* We only need two zones for kernel and user-level processes */
#define TLB_SU_ZONE	0	/* Kernel-only access controlled permission bits in TLB */
#define TLB_U_ZONE	1	/* Access always controlled by permission bits in TLB entry */

#define TLB_HI(epn,size,flags)	(((epn)&TLB_EPN_MASK)|(((size)<<TLB_SIZE_SHFT)&TLB_SIZE_MASK)|(flags))
#define TLB_LO(rpn,zone,flags)	(((rpn)&TLB_RPN_MASK)|(((zone)<<TLB_ZSEL_SHFT)&TLB_ZSEL_MASK)|(flags))

#ifndef _LOCORE

typedef struct tlb_s {
	u_int tlb_hi;
	u_int tlb_lo;
} tlb_t;

struct	pmap;

void	ppc4xx_tlb_enter(int, vaddr_t, u_int);
void	ppc4xx_tlb_flush(vaddr_t, int);
void	ppc4xx_tlb_flush_all(void);
void	ppc4xx_tlb_init(void);
int	ppc4xx_tlb_new_pid(struct pmap *);
void	ppc4xx_tlb_reserve(paddr_t, vaddr_t, size_t, int);
void 	*ppc4xx_tlb_mapiodev(paddr_t, psize_t);

#ifndef ppc4xx_tlbflags
#define	ppc4xx_tlbflags(va, pa)	(0)
#endif

#endif /* !_LOCORE */

#define TLB_PID_INVALID 0xFFFF

#endif	/* _IBM4XX_TLB_H_ */