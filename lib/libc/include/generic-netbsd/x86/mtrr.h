/* $NetBSD: mtrr.h,v 1.6 2020/01/31 08:21:11 maxv Exp $ */

/*-
 * Copyright (c) 2000 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Bill Sommerfeld
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

#ifndef _X86_MTRR_H_
#define _X86_MTRR_H_

#define MTRR_I686_FIXED_IDX64K	0
#define MTRR_I686_FIXED_IDX16K	1
#define MTRR_I686_FIXED_IDX4K	3

#define MTRR_I686_NVAR_MAX	16	/* could be upto 255? */

#define MTRR_I686_64K_START		0x00000
#define MTRR_I686_16K_START		0x80000
#define MTRR_I686_4K_START		0xc0000

#define MTRR_I686_NFIXED_64K		1
#define MTRR_I686_NFIXED_16K		2
#define MTRR_I686_NFIXED_4K		8
#define MTRR_I686_NFIXED		11
#define MTRR_I686_NFIXED_SOFT_64K	(MTRR_I686_NFIXED_64K * 8)
#define MTRR_I686_NFIXED_SOFT_16K	(MTRR_I686_NFIXED_16K * 8)
#define MTRR_I686_NFIXED_SOFT_4K	(MTRR_I686_NFIXED_4K * 8)
#define MTRR_I686_NFIXED_SOFT		(MTRR_I686_NFIXED * 8)

#define MTRR_I686_ENABLE_MASK	0x0800
#define MTRR_I686_FIXED_ENABLE_MASK	0x0400

#define MTRR_I686_CAP_VCNT_MASK	0x00ff
#define MTRR_I686_CAP_FIX_MASK	0x0100
#define MTRR_I686_CAP_WC_MASK	0x0400

#define MTRR_TYPE_UC		0
#define MTRR_TYPE_WC		1
#define MTRR_TYPE_UNDEF1	2
#define MTRR_TYPE_UNDEF2	3
#define MTRR_TYPE_WT		4
#define MTRR_TYPE_WP		5
#define MTRR_TYPE_WB		6

struct mtrr_state {
	uint32_t msraddr;
	uint64_t msrval;
};
	
#define MTRR_PRIVATE	0x0001		/* 'own' range, reset at exit */
#define MTRR_FIXED	0x0002		/* use fixed range mtrr */
#define MTRR_VALID	0x0004		/* entry is valid */

#define MTRR_CANTSET	MTRR_FIXED

#define MTRR_I686_MASK_VALID	(1 << 11)

/*
 * AMD K6 MTRRs.
 *
 * There are two of these MTRR-like registers in the UWCRR.
 */

#define	MTRR_K6_ADDR_SHIFT 17
#define	MTRR_K6_ADDR	(0x7fffU << MTRR_K6_ADDR_SHIFT)
#define	MTRR_K6_MASK_SHIFT 2
#define	MTRR_K6_MASK	(0x7fffU << MTRR_K6_MASK_SHIFT)
#define	MTRR_K6_WC	(1U << 1)	/* write-combine */
#define	MTRR_K6_UC	(1U << 0)	/* uncached */

#define	MTRR_K6_NVAR	2

#ifdef _KERNEL

#define mtrr_base_value(mtrrp) \
    (((uint64_t)(mtrrp)->base) | ((uint64_t)(mtrrp)->type))
#define mtrr_mask_value(mtrrp) \
    ((~((mtrrp)->len - 1) & 0x0000000ffffff000LL))
	

#define mtrr_len(val) \
    ((~((val) & 0x0000000ffffff000LL)+1) & 0x0000000ffffff000LL)
#define mtrr_base(val)		((val) & 0x0000000ffffff000LL)
#define mtrr_type(val)		((uint8_t)((val) & 0x00000000000000ffLL))
#define mtrr_valid(val)		(((val) & MTRR_I686_MASK_VALID) != 0)

struct proc;
struct mtrr;

void i686_mtrr_init_first(void);
void k6_mtrr_init_first(void);

struct mtrr_funcs {
	void (*init_cpu)(struct cpu_info *ci);
	void (*reload_cpu)(struct cpu_info *ci);
	void (*clean)(struct proc *p);
	int (*set)(struct mtrr *, int *n, struct proc *p, int flags);
	int (*get)(struct mtrr *, int *n, struct proc *p, int flags);
	void (*commit)(void);
	void (*dump)(const char *tag);
};

extern const struct mtrr_funcs i686_mtrr_funcs;
extern const struct mtrr_funcs k6_mtrr_funcs;
extern const struct mtrr_funcs *mtrr_funcs;

#define mtrr_init_cpu(ci)	mtrr_funcs->init_cpu(ci)
#define mtrr_reload_cpu(ci)	mtrr_funcs->reload_cpu(ci)
#define mtrr_clean(p)		mtrr_funcs->clean(p)
#define mtrr_set(mp,n,p,f)	mtrr_funcs->set(mp,n,p,f)
#define mtrr_get(mp,n,p,f)	mtrr_funcs->get(mp,n,p,f)
#define mtrr_dump(s)		mtrr_funcs->dump(s)
#define mtrr_commit()		mtrr_funcs->commit()

#define MTRR_GETSET_USER	0x0001
#define MTRR_GETSET_KERNEL	0x0002

#endif /* _KERNEL */

struct mtrr {
	uint64_t base;		/* physical base address */
	uint64_t len;
	uint8_t type;
	int flags;
	pid_t owner;		/* valid if MTRR_PRIVATE set in flags */
};

#endif /* _X86_MTRR_H_ */