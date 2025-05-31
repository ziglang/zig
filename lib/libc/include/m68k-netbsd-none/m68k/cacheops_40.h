/*	$NetBSD: cacheops_40.h,v 1.11 2008/04/28 20:23:26 martin Exp $	*/

/*-
 * Copyright (c) 1997 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Leo Weppelman
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

/*
 * Invalidate entire TLB.
 */
static __inline void __attribute__((__unused__))
TBIA_40(void)
{
	__asm volatile (" .word 0xf518" ); /*  pflusha */
}

/*
 * Invalidate any TLB entry for given VA (TB Invalidate Single)
 */
static __inline void __attribute__((__unused__))
TBIS_40(vaddr_t va)
{
	register uint8_t *r_va __asm("%a0") = (void *)va;
	int	tmp;

	__asm volatile (" movc   %1, %%dfc;"	/* select supervisor	*/
			  " .word 0xf508;"	/* pflush %a0@		*/
			  " moveq  %3, %1;"	/* select user		*/
			  " movc   %1, %%dfc;"
			  " .word 0xf508;" : "=d" (tmp) :
			  "0" (FC_SUPERD), "a" (r_va), "i" (FC_USERD));
}

/*
 * Invalidate supervisor side of TLB
 */
static __inline void __attribute__((__unused__))
TBIAS_40(void)
{
	/*
	 * Cannot specify supervisor/user on pflusha, so we flush all
	 */
	__asm volatile (" .word 0xf518;");
}

/*
 * Invalidate user side of TLB
 */
static __inline void __attribute__((__unused__))
TBIAU_40(void)
{
	/*
	 * Cannot specify supervisor/user on pflusha, so we flush all
	 */
	__asm volatile (" .word 0xf518;");
}

/*
 * Invalidate instruction cache
 */
static __inline void __attribute__((__unused__))
ICIA_40(void)
{
	__asm volatile (" .word 0xf498;"); /* cinva ic */
}

static __inline void __attribute__((__unused__))
ICPA_40(void)
{
	__asm volatile (" .word 0xf498;"); /* cinva ic */
}

/*
 * Invalidate data cache.
 */
static __inline void __attribute__((__unused__))
DCIA_40(void)
{
	__asm volatile (" .word 0xf478;"); /* cpusha dc */
}

static __inline void __attribute__((__unused__))
DCIS_40(void)
{
	__asm volatile (" .word 0xf478;"); /* cpusha dc */
}

static __inline void __attribute__((__unused__))
DCIU_40(void)
{
	__asm volatile (" .word 0xf478;"); /* cpusha dc */
}

static __inline void __attribute__((__unused__))
DCIAS_40(paddr_t pa)
{
	register uint8_t *r_pa __asm("%a0") = (void *)pa;

	__asm volatile (" .word 0xf468;" : : "a" (r_pa)); /* cpushl dc,%a0@ */
}

static __inline void __attribute__((__unused__))
PCIA_40(void)
{
	__asm volatile (" .word 0xf478;"); /* cpusha dc */
}

static __inline void __attribute__((__unused__))
DCFA_40(void)
{
	__asm volatile (" .word 0xf478;"); /* cpusha dc */
}

/* invalidate instruction physical cache line */
static __inline void __attribute__((__unused__))
ICPL_40(paddr_t pa)
{
	register uint8_t *r_pa __asm("%a0") = (void *)pa;

	__asm volatile (" .word 0xf488;" : : "a" (r_pa)); /* cinvl ic,%a0@ */
}

/* invalidate instruction physical cache page */
static __inline void __attribute__((__unused__))
ICPP_40(paddr_t pa)
{
	register uint8_t *r_pa __asm("%a0") = (void *)pa;

	__asm volatile (" .word 0xf490;" : : "a" (r_pa)); /* cinvp ic,%a0@ */
}

/* invalidate data physical cache line */
static __inline void __attribute__((__unused__))
DCPL_40(paddr_t pa)
{
	register uint8_t *r_pa __asm("%a0") = (void *)pa;

	__asm volatile (" .word 0xf448;" : : "a" (r_pa)); /* cinvl dc,%a0@ */
}

/* invalidate data physical cache page */
static __inline void __attribute__((__unused__))
DCPP_40(paddr_t pa)
{
	register uint8_t *r_pa __asm("%a0") = (void *)pa;

	__asm volatile (" .word 0xf450;" : : "a" (r_pa)); /* cinvp dc,%a0@ */
}

/* invalidate data physical all */
static __inline void __attribute__((__unused__))
DCPA_40(void)
{
	__asm volatile (" .word 0xf458;"); /* cinva dc */
}

/* data cache flush line */
static __inline void __attribute__((__unused__))
DCFL_40(paddr_t pa)
{
	register uint8_t *r_pa __asm("%a0") = (void *)pa;

	__asm volatile (" .word 0xf468;" : : "a" (r_pa)); /* cpushl dc,%a0@ */
}

/* data cache flush page */
static __inline void __attribute__((__unused__))
DCFP_40(paddr_t pa)
{
	register uint8_t *r_pa __asm("%a0") = (void *)pa;

	__asm volatile (" .word 0xf470;" : : "a" (r_pa)); /* cpushp dc,%a0@ */
}