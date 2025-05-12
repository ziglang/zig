/*	$NetBSD: spr.h,v 1.56 2022/05/07 09:02:19 rin Exp $	*/

/*
 * Copyright (c) 2001, The NetBSD Foundation, Inc.
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
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _POWERPC_SPR_H_
#define	_POWERPC_SPR_H_

#if !defined(_LOCORE) && defined(_KERNEL)

#ifdef _KERNEL_OPT
#include "opt_ppcarch.h"
#endif

#include <powerpc/oea/cpufeat.h>

#if defined(PPC_OEA64_BRIDGE) || defined (_ARCH_PPC64)
static __inline uint64_t
mfspr64(int reg)
{
	uint64_t ret;
	register_t hi, l;

	__asm volatile( "mfspr %0,%2;"
			"srdi %1,%0,32;"
			 : "=r"(l), "=r"(hi) : "K"(reg));
	ret = ((uint64_t)hi << 32) | l;
	return ret;
}

/* This as an inline breaks as 'reg' ends up not being an immediate */
#define mtspr64(reg, v)						\
( {								\
	volatile register_t hi, l;				\
								\
	uint64_t val = v;					\
	hi = (val >> 32);					\
	l = val & 0xffffffff;					\
	__asm volatile(	"sldi %2,%2,32;"			\
			"or %2,%2,%1;"				\
			"sync;"					\
			"mtspr %0,%2;"				\
			"mfspr %2,%0;"				\
			"mfspr %2,%0;"				\
			"mfspr %2,%0;"				\
			"mfspr %2,%0;"				\
			"mfspr %2,%0;"				\
			"mfspr %2,%0;"				\
			 : : "K"(reg), "r"(l), "r"(hi));		\
} )
#endif /* PPC_OEA64_BRIDGE || _ARCH_PPC64 */

static __inline __always_inline uint64_t
mfspr32(const int reg)
{
	register_t val;

	__asm volatile("mfspr %0,%1" : "=r"(val) : "K"(reg));
	return val;
}

static __inline __always_inline void
mtspr32(const int reg, uint32_t val)
{

	__asm volatile("mtspr %0,%1" : : "K"(reg), "r"(val));
}

#if (defined(PPC_OEA) + defined(PPC_OEA64) + defined(PPC_OEA64_BRIDGE)) > 1
static __inline uint64_t
mfspr(int reg)
{
	if ((oeacpufeat & (OEACPU_64_BRIDGE|OEACPU_64)) != 0)
		return mfspr64(reg);
	return mfspr32(reg);
}

/* This as an inline breaks as 'reg' ends up not being an immediate */
#define mtspr(reg, val)						\
( {								\
	if ((oeacpufeat & (OEACPU_64_BRIDGE|OEACPU_64)) != 0)	\
		mtspr64(reg, (uint64_t)val);			\
	else							\
		mtspr32(reg, val);				\
} )
#else /* PPC_OEA + PPC_OEA64 + PPC_OEA64_BRIDGE != 1 */

#if defined(PPC_OEA64) || defined(PPC_OEA64_BRIDGE)
#define mfspr(r) mfspr64(r)
#define mtspr(r,v) mtspr64(r,v)
#else
#define mfspr(r) mfspr32(r)
#define mtspr(r,v) mtspr32(r,v)
#endif

#endif /* PPC_OEA + PPC_OEA64 + PPC_OEA64_BRIDGE > 1 */

#endif /* !_LOCORE && _KERNEL */

/*
 * Special Purpose Register declarations.
 *
 * The first column in the comments indicates which PowerPC architectures the
 * SPR is valid on - E for BookE series, 4 for 4xx series,
 * 6 for 6xx/7xx series and 8 for 8xx and 8xxx (but not 85xx) series.
 */

#define	SPR_XER			0x001	/* E468 Fixed Point Exception Register */
#define	SPR_LR			0x008	/* E468 Link Register */
#define	SPR_CTR			0x009	/* E468 Count Register */
#define	SPR_DEC			0x016	/* E468 DECrementer register */
#define	SPR_SRR0		0x01a	/* E468 Save/Restore Register 0 */
#define	SPR_SRR1		0x01b	/* E468 Save/Restore Register 1 */
#define	SPR_SPRG0		0x110	/* E468 SPR General 0 */
#define	SPR_SPRG1		0x111	/* E468 SPR General 1 */
#define	SPR_SPRG2		0x112	/* E468 SPR General 2 */
#define	SPR_SPRG3		0x113	/* E468 SPR General 3 */
#define	SPR_SPRG4		0x114	/* E4.. SPR General 4 */
#define	SPR_SPRG5		0x115	/* E4.. SPR General 5 */
#define	SPR_SPRG6		0x116	/* E4.. SPR General 6 */
#define	SPR_SPRG7		0x117	/* E4.. SPR General 7 */
#define	SPR_TBL			0x11c	/* E468 Time Base Lower */
#define	SPR_TBU			0x11d	/* E468 Time Base Upper */
#define	SPR_PVR			0x11f	/* E468 Processor Version Register */

/* Time Base Register declarations */
#define	TBR_TBL			0x10c	/* E468 Time Base Lower */
#define	TBR_TBU			0x10d	/* E468 Time Base Upper */

#endif /* !_POWERPC_SPR_H_ */