/*	$NetBSD: pool.h,v 1.96 2021/12/22 16:57:28 thorpej Exp $	*/

/*-
 * Copyright (c) 1997, 1998, 1999, 2000, 2007, 2020
 *     The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Paul Kranenburg; by Jason R. Thorpe of the Numerical Aerospace
 * Simulation Facility, NASA Ames Research Center.
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

#ifndef _SYS_POOL_H_
#define _SYS_POOL_H_

#include <sys/stdbool.h>
#include <sys/stdint.h>

struct pool_sysctl {
	char pr_wchan[16];
	uint64_t pr_flags;
	uint64_t pr_size;
	uint64_t pr_pagesize;
	uint64_t pr_itemsperpage;
	uint64_t pr_nitems;
	uint64_t pr_nout;
	uint64_t pr_hardlimit;
	uint64_t pr_npages;
	uint64_t pr_minpages;
	uint64_t pr_maxpages;

	uint64_t pr_nget;
	uint64_t pr_nfail;
	uint64_t pr_nput;
	uint64_t pr_npagealloc;
	uint64_t pr_npagefree;
	uint64_t pr_hiwat;
	uint64_t pr_nidle;

	uint64_t pr_cache_meta_size;
	uint64_t pr_cache_nfull;
	uint64_t pr_cache_npartial;
	uint64_t pr_cache_nempty;
	uint64_t pr_cache_ncontended;
	uint64_t pr_cache_nmiss_global;
	uint64_t pr_cache_nhit_global;
	uint64_t pr_cache_nmiss_pcpu;
	uint64_t pr_cache_nhit_pcpu;
};

#ifdef _KERNEL
#define __POOL_EXPOSE
#endif

#ifdef __POOL_EXPOSE
#include <sys/param.h>
#include <sys/mutex.h>
#include <sys/condvar.h>
#include <sys/queue.h>
#include <sys/time.h>
#include <sys/tree.h>
#include <sys/callback.h>

#ifdef _KERNEL_OPT
#include "opt_pool.h"
#endif

#define POOL_PADDR_INVALID	((paddr_t) -1)

struct pool;

struct pool_allocator {
	void		*(*pa_alloc)(struct pool *, int);
	void		(*pa_free)(struct pool *, void *);
	unsigned int	pa_pagesz;

	/* The following fields are for internal use only. */
	kmutex_t	pa_lock;
	TAILQ_HEAD(, pool) pa_list;	/* list of pools using this allocator */
	uint32_t	pa_refcnt;	/* number of pools using this allocator */
	int		pa_pagemask;
	int		pa_pageshift;
};

LIST_HEAD(pool_pagelist,pool_item_header);
SPLAY_HEAD(phtree, pool_item_header);

#define POOL_QUARANTINE_DEPTH	128
typedef struct {
	size_t rotor;
	intptr_t list[POOL_QUARANTINE_DEPTH];
} pool_quar_t;

struct pool {
	TAILQ_ENTRY(pool)
			pr_poollist;
	struct pool_pagelist
			pr_emptypages;	/* Empty pages */
	struct pool_pagelist
			pr_fullpages;	/* Full pages */
	struct pool_pagelist
			pr_partpages;	/* Partially-allocated pages */
	struct pool_item_header	*pr_curpage;
	struct pool	*pr_phpool;	/* Pool item header pool */
	struct pool_cache *pr_cache;	/* Cache for this pool */
	unsigned int	pr_size;	/* Size of item */
	unsigned int	pr_align;	/* Requested alignment, must be 2^n */
	unsigned int	pr_itemoffset;	/* offset of the item space */
	unsigned int	pr_minitems;	/* minimum # of free items to keep */
	unsigned int	pr_maxitems;	/* maximum # of free items to keep */
	unsigned int	pr_minpages;	/* minimum # of pages to keep */
	unsigned int	pr_maxpages;	/* maximum # of pages to keep */
	unsigned int	pr_npages;	/* # of pages allocated */
	unsigned int	pr_itemsperpage;/* # items that fit in a page */
	unsigned int	pr_poolid;	/* id of the pool */
	unsigned int	pr_nitems;	/* number of free items in pool */
	unsigned int	pr_nout;	/* # items currently allocated */
	unsigned int	pr_hardlimit;	/* hard limit to number of allocated
					   items */
	unsigned int	pr_refcnt;	/* ref count for pagedaemon, etc */
	struct pool_allocator *pr_alloc;/* back-end allocator */
	TAILQ_ENTRY(pool) pr_alloc_list;/* link on allocator's pool list */

	/* Drain hook. */
	void		(*pr_drain_hook)(void *, int);
	void		*pr_drain_hook_arg;

	const char	*pr_wchan;	/* tsleep(9) identifier */
	unsigned int	pr_flags;	/* r/w flags */
	unsigned int	pr_roflags;	/* r/o flags */
#define PR_WAITOK	0x01	/* Note: matches KM_SLEEP */
#define PR_NOWAIT	0x02	/* Note: matches KM_NOSLEEP */
#define PR_WANTED	0x04	/* waiting for free objects */
#define PR_PHINPAGE	0x40	/* page header in page */
#define PR_LIMITFAIL	0x100	/* even if waiting, fail if we hit limit */
#define PR_RECURSIVE	0x200	/* pool contains pools, for vmstat(8) */
#define PR_NOTOUCH	0x400	/* don't use free items to keep internal state*/
#define PR_NOALIGN	0x800	/* don't assume backend alignment */
#define PR_LARGECACHE	0x1000	/* use large cache groups */
#define PR_GROWING	0x2000	/* pool_grow in progress */
#define PR_GROWINGNOWAIT 0x4000	/* pool_grow in progress by PR_NOWAIT alloc */
#define PR_ZERO		0x8000	/* zero data before returning */
#define PR_USEBMAP	0x10000	/* use a bitmap to manage freed items */
#define PR_PSERIALIZE	0x20000	/* needs pserialize sync point before free */

	/*
	 * `pr_lock' protects the pool's data structures when removing
	 * items from or returning items to the pool, or when reading
	 * or updating read/write fields in the pool descriptor.
	 *
	 * We assume back-end page allocators provide their own locking
	 * scheme.  They will be called with the pool descriptor _unlocked_,
	 * since the page allocators may block.
	 */
	kmutex_t	pr_lock;
	kcondvar_t	pr_cv;
	int		pr_ipl;

	struct phtree	pr_phtree;

	int		pr_maxcolor;	/* Cache colouring */
	int		pr_curcolor;
	int		pr_phoffset;	/* unused */

	/*
	 * Warning message to be issued, and a per-time-delta rate cap,
	 * if the hard limit is reached.
	 */
	const char	*pr_hardlimit_warning;
	struct timeval	pr_hardlimit_ratecap;
	struct timeval	pr_hardlimit_warning_last;

	/*
	 * Instrumentation
	 */
	unsigned long	pr_nget;	/* # of successful requests */
	unsigned long	pr_nfail;	/* # of unsuccessful requests */
	unsigned long	pr_nput;	/* # of releases */
	unsigned long	pr_npagealloc;	/* # of pages allocated */
	unsigned long	pr_npagefree;	/* # of pages released */
	unsigned int	pr_hiwat;	/* max # of pages in pool */
	unsigned long	pr_nidle;	/* # of idle pages */

	/*
	 * Diagnostic aides.
	 */
	void		*pr_freecheck;
	void		*pr_qcache;
	bool		pr_redzone;
	size_t		pr_reqsize;
	size_t		pr_reqsize_with_redzone;
#ifdef POOL_QUARANTINE
	pool_quar_t	pr_quar;
#endif
};

/*
 * Cache group sizes, assuming 4-byte paddr_t on !_LP64.
 * All groups will be aligned to COHERENCY_UNIT.
 */
#ifdef _LP64
#define PCG_NOBJECTS_NORMAL	15	/* 256 byte group */
#define PCG_NOBJECTS_LARGE	63	/* 1024 byte group */
#else
#define PCG_NOBJECTS_NORMAL	14	/* 124 byte group */
#define PCG_NOBJECTS_LARGE	62	/* 508 byte group */
#endif

typedef struct pcgpair {
	void	*pcgo_va;		/* object virtual address */
	paddr_t	pcgo_pa;		/* object physical address */
} pcgpair_t;

/* The pool cache group. */
typedef struct pool_cache_group {
	struct pool_cache_group	*pcg_next;	/* link to next group */
	u_int			pcg_avail;	/* # available objects */
	u_int			pcg_size;	/* max number objects */
	pcgpair_t 		pcg_objects[1];	/* the objects */
} pcg_t;

/* Pool cache CPU.  Sized to 64 bytes on _LP64. */
typedef struct pool_cache_cpu {
	struct pool_cache_group	*cc_current;
	struct pool_cache_group	*cc_previous;	
	pcg_t *volatile 	*cc_pcgcache;
	uint64_t		cc_misses;
	uint64_t		cc_hits;
	uint64_t		cc_pcmisses;
	uint64_t		cc_contended;
	uint32_t		cc_nfull;
	uint32_t		cc_npart;
} pool_cache_cpu_t;

struct pool_cache {
	/* Pool layer. */
	struct pool	pc_pool;
	
	/* Cache layer. */
	TAILQ_ENTRY(pool_cache)
			pc_cachelist;	/* entry on global cache list */
	struct pool	*pc_pcgpool;	/* Pool of cache groups */
	pcg_t *volatile *pc_pcgcache;	/* list of empty cache groups */
	int		pc_pcgsize;	/* Use large cache groups? */
	int		pc_ncpu;	/* number cpus set up */
	int		(*pc_ctor)(void *, void *, int);
	void		(*pc_dtor)(void *, void *);
	void		*pc_arg;	/* for ctor/dtor */
	unsigned int	pc_refcnt;	/* ref count for pagedaemon, etc */
	unsigned int	pc_roflags;	/* r/o cache flags */
	void		*pc_cpus[MAXCPUS];

	/* Diagnostic aides. */
	void		*pc_freecheck;
	bool		pc_redzone;
	size_t		pc_reqsize;

	/* Hot items. */
	pcg_t *volatile pc_fullgroups	/* list of full cache groups */
	    __aligned(CACHE_LINE_SIZE);
	pcg_t *volatile pc_partgroups;	/* groups for reclamation */

	/* Boot cpu. */
	pool_cache_cpu_t pc_cpu0 __aligned(CACHE_LINE_SIZE);
};

#endif /* __POOL_EXPOSE */

typedef struct pool_cache *pool_cache_t;

#ifdef _KERNEL
/*
 * pool_allocator_kmem is the default that all pools get unless
 * otherwise specified.  pool_allocator_nointr is provided for
 * pools that know they will never be accessed in interrupt
 * context.
 */
extern struct pool_allocator pool_allocator_kmem;
extern struct pool_allocator pool_allocator_nointr;
extern struct pool_allocator pool_allocator_meta;

void		pool_subsystem_init(void);

void		pool_init(struct pool *, size_t, u_int, u_int,
		    int, const char *, struct pool_allocator *, int);
void		pool_destroy(struct pool *);

void		pool_set_drain_hook(struct pool *,
		    void (*)(void *, int), void *);

void		*pool_get(struct pool *, int);
void		pool_put(struct pool *, void *);
int		pool_reclaim(struct pool *);

void		pool_prime(struct pool *, int);
void		pool_setlowat(struct pool *, int);
void		pool_sethiwat(struct pool *, int);
void		pool_sethardlimit(struct pool *, int, const char *, int);
bool		pool_drain(struct pool **);
int		pool_totalpages(void);
int		pool_totalpages_locked(void);

unsigned int	pool_nget(struct pool *);
unsigned int	pool_nput(struct pool *);

/*
 * Debugging and diagnostic aides.
 */
void		pool_printit(struct pool *, const char *,
    void (*)(const char *, ...) __printflike(1, 2));
void		pool_printall(const char *, void (*)(const char *, ...)
    __printflike(1, 2));
int		pool_chk(struct pool *, const char *);

/*
 * Pool cache routines.
 */
pool_cache_t	pool_cache_init(size_t, u_int, u_int, u_int, const char *,
		    struct pool_allocator *, int, int (*)(void *, void *, int),
		    void (*)(void *, void *), void *);
void		pool_cache_bootstrap(pool_cache_t, size_t, u_int, u_int, u_int,
		    const char *, struct pool_allocator *, int,
		    int (*)(void *, void *, int), void (*)(void *, void *),
		    void *);
void		pool_cache_destroy(pool_cache_t);
void		pool_cache_bootstrap_destroy(pool_cache_t);
void		*pool_cache_get_paddr(pool_cache_t, int, paddr_t *);
void		pool_cache_put_paddr(pool_cache_t, void *, paddr_t);
void		pool_cache_destruct_object(pool_cache_t, void *);
void		pool_cache_invalidate(pool_cache_t);
bool		pool_cache_reclaim(pool_cache_t);
void		pool_cache_set_drain_hook(pool_cache_t,
		    void (*)(void *, int), void *);
void		pool_cache_setlowat(pool_cache_t, int);
void		pool_cache_sethiwat(pool_cache_t, int);
void		pool_cache_sethardlimit(pool_cache_t, int, const char *, int);
void		pool_cache_prime(pool_cache_t, int);
void		pool_cache_cpu_init(struct cpu_info *);

unsigned int	pool_cache_nget(pool_cache_t);
unsigned int	pool_cache_nput(pool_cache_t);

#define		pool_cache_get(pc, f) pool_cache_get_paddr((pc), (f), NULL)
#define		pool_cache_put(pc, o) pool_cache_put_paddr((pc), (o), \
				          POOL_PADDR_INVALID)

void		pool_whatis(uintptr_t, void (*)(const char *, ...)
    __printflike(1, 2));
#endif /* _KERNEL */

#endif /* _SYS_POOL_H_ */