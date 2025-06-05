/*	$NetBSD: uvm_pglist.h,v 1.11 2020/04/13 15:16:14 ad Exp $	*/

/*-
 * Copyright (c) 2000, 2001, 2008, 2019 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe, and by Andrew Doran.
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

#ifndef _UVM_UVM_PGLIST_H_
#define _UVM_UVM_PGLIST_H_

#include <sys/param.h>

/*
 * This defines the type of a page queue, e.g. active list, inactive
 * list, etc.
 */
struct vm_page;
TAILQ_HEAD(pglist, vm_page);
LIST_HEAD(pgflist, vm_page);

/*
 * The global uvm.page_free list (uvm_page.c, uvm_pglist.c).  Free pages are
 * stored according to freelist, bucket, and cache colour.
 *
 * pglist = &uvm.page_free[freelist].pgfl_buckets[bucket].pgb_color[color];
 *
 * Freelists provide a priority ordering of pages for allocation, based upon
 * how valuable they are for special uses (e.g.  device driver DMA).  MD
 * code decides the number and structure of these.  They are always arranged
 * in descending order of allocation priority.
 *
 * Pages are then grouped in buckets according to some common factor, for
 * example L2/L3 cache locality.  Each bucket has its own lock, and the
 * locks are shared among freelists for the same numbered buckets.
 *
 * Inside each bucket, pages are further distributed by cache color.
 *
 * We want these data structures to occupy as few cache lines as possible,
 * as they will be highly contended.
 */
struct pgflbucket {
	uintptr_t	pgb_nfree;	/* total # free pages, all colors */
	struct pgflist	pgb_colors[1];	/* variable size array */
};

/*
 * 8 buckets should be enough to cover most all current x86 systems (2019),
 * given the way package/core/smt IDs are structured on x86.  For systems
 * that report high package counts despite having a single physical CPU
 * package (e.g. Ampere eMAG) a little bit of sharing isn't going to hurt.
 */
#define	PGFL_MAX_BUCKETS	8
struct pgfreelist {
	struct pgflbucket	*pgfl_buckets[PGFL_MAX_BUCKETS];
};

/*
 * Lock for each bucket.
 */
union uvm_freelist_lock {
        kmutex_t        lock;
        uint8_t         padding[COHERENCY_UNIT];
};
extern union uvm_freelist_lock	uvm_freelist_locks[PGFL_MAX_BUCKETS];

#endif /* _UVM_UVM_PGLIST_H_ */