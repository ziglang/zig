/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2002-2019 Jeffrey Roberson <jeff@FreeBSD.org>
 * Copyright (c) 2004, 2005 Bosko Milekic <bmilekic@FreeBSD.org>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice unmodified, this list of conditions, and the following
 *    disclaimer.
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
 *
 */

#include <sys/counter.h>
#include <sys/_bitset.h>
#include <sys/_domainset.h>
#include <sys/_task.h>

/* 
 * This file includes definitions, structures, prototypes, and inlines that
 * should not be used outside of the actual implementation of UMA.
 */

/* 
 * The brief summary;  Zones describe unique allocation types.  Zones are
 * organized into per-CPU caches which are filled by buckets.  Buckets are
 * organized according to memory domains.  Buckets are filled from kegs which
 * are also organized according to memory domains.  Kegs describe a unique
 * allocation type, backend memory provider, and layout.  Kegs are associated
 * with one or more zones and zones reference one or more kegs.  Kegs provide
 * slabs which are virtually contiguous collections of pages.  Each slab is
 * broken down int one or more items that will satisfy an individual allocation.
 *
 * Allocation is satisfied in the following order:
 * 1) Per-CPU cache
 * 2) Per-domain cache of buckets
 * 3) Slab from any of N kegs
 * 4) Backend page provider
 *
 * More detail on individual objects is contained below:
 *
 * Kegs contain lists of slabs which are stored in either the full bin, empty
 * bin, or partially allocated bin, to reduce fragmentation.  They also contain
 * the user supplied value for size, which is adjusted for alignment purposes
 * and rsize is the result of that.  The Keg also stores information for
 * managing a hash of page addresses that maps pages to uma_slab_t structures
 * for pages that don't have embedded uma_slab_t's.
 *
 * Keg slab lists are organized by memory domain to support NUMA allocation
 * policies.  By default allocations are spread across domains to reduce the
 * potential for hotspots.  Special keg creation flags may be specified to
 * prefer location allocation.  However there is no strict enforcement as frees
 * may happen on any CPU and these are returned to the CPU-local cache
 * regardless of the originating domain.
 *  
 * The uma_slab_t may be embedded in a UMA_SLAB_SIZE chunk of memory or it may
 * be allocated off the page from a special slab zone.  The free list within a
 * slab is managed with a bitmask.  For item sizes that would yield more than
 * 10% memory waste we potentially allocate a separate uma_slab_t if this will
 * improve the number of items per slab that will fit.  
 *
 * The only really gross cases, with regards to memory waste, are for those
 * items that are just over half the page size.   You can get nearly 50% waste,
 * so you fall back to the memory footprint of the power of two allocator. I
 * have looked at memory allocation sizes on many of the machines available to
 * me, and there does not seem to be an abundance of allocations at this range
 * so at this time it may not make sense to optimize for it.  This can, of 
 * course, be solved with dynamic slab sizes.
 *
 * Kegs may serve multiple Zones but by far most of the time they only serve
 * one.  When a Zone is created, a Keg is allocated and setup for it.  While
 * the backing Keg stores slabs, the Zone caches Buckets of items allocated
 * from the slabs.  Each Zone is equipped with an init/fini and ctor/dtor
 * pair, as well as with its own set of small per-CPU caches, layered above
 * the Zone's general Bucket cache.
 *
 * The PCPU caches are protected by critical sections, and may be accessed
 * safely only from their associated CPU, while the Zones backed by the same
 * Keg all share a common Keg lock (to coalesce contention on the backing
 * slabs).  The backing Keg typically only serves one Zone but in the case of
 * multiple Zones, one of the Zones is considered the Primary Zone and all
 * Zone-related stats from the Keg are done in the Primary Zone.  For an
 * example of a Multi-Zone setup, refer to the Mbuf allocation code.
 */

/*
 *	This is the representation for normal (Non OFFPAGE slab)
 *
 *	i == item
 *	s == slab pointer
 *
 *	<----------------  Page (UMA_SLAB_SIZE) ------------------>
 *	___________________________________________________________
 *     | _  _  _  _  _  _  _  _  _  _  _  _  _  _  _   ___________ |
 *     ||i||i||i||i||i||i||i||i||i||i||i||i||i||i||i| |slab header||
 *     ||_||_||_||_||_||_||_||_||_||_||_||_||_||_||_| |___________|| 
 *     |___________________________________________________________|
 *
 *
 *	This is an OFFPAGE slab. These can be larger than UMA_SLAB_SIZE.
 *
 *	___________________________________________________________
 *     | _  _  _  _  _  _  _  _  _  _  _  _  _  _  _  _  _  _  _   |
 *     ||i||i||i||i||i||i||i||i||i||i||i||i||i||i||i||i||i||i||i|  |
 *     ||_||_||_||_||_||_||_||_||_||_||_||_||_||_||_||_||_||_||_|  |
 *     |___________________________________________________________|
 *       ___________    ^
 *	|slab header|   |
 *	|___________|---*
 *
 */

#ifndef VM_UMA_INT_H
#define VM_UMA_INT_H

#define UMA_SLAB_SIZE	PAGE_SIZE	/* How big are our slabs? */
#define UMA_SLAB_MASK	(PAGE_SIZE - 1)	/* Mask to get back to the page */
#define UMA_SLAB_SHIFT	PAGE_SHIFT	/* Number of bits PAGE_MASK */

/* Max waste percentage before going to off page slab management */
#define UMA_MAX_WASTE	10

/* Max size of a CACHESPREAD slab. */
#define	UMA_CACHESPREAD_MAX_SIZE	(128 * 1024)

/*
 * These flags must not overlap with the UMA_ZONE flags specified in uma.h.
 */
#define	UMA_ZFLAG_OFFPAGE	0x00200000	/*
						 * Force the slab structure
						 * allocation off of the real
						 * memory.
						 */
#define	UMA_ZFLAG_HASH		0x00400000	/*
						 * Use a hash table instead of
						 * caching information in the
						 * vm_page.
						 */
#define	UMA_ZFLAG_VTOSLAB	0x00800000	/*
						 * Zone uses vtoslab for
						 * lookup.
						 */
#define	UMA_ZFLAG_CTORDTOR	0x01000000	/* Zone has ctor/dtor set. */
#define	UMA_ZFLAG_LIMIT		0x02000000	/* Zone has limit set. */
#define	UMA_ZFLAG_CACHE		0x04000000	/* uma_zcache_create()d it */
#define	UMA_ZFLAG_BUCKET	0x10000000	/* Bucket zone. */
#define	UMA_ZFLAG_INTERNAL	0x20000000	/* No offpage no PCPU. */
#define	UMA_ZFLAG_TRASH		0x40000000	/* Add trash ctor/dtor. */

#define	UMA_ZFLAG_INHERIT						\
    (UMA_ZFLAG_OFFPAGE | UMA_ZFLAG_HASH | UMA_ZFLAG_VTOSLAB |		\
     UMA_ZFLAG_BUCKET | UMA_ZFLAG_INTERNAL)

#define	PRINT_UMA_ZFLAGS	"\20"	\
    "\37TRASH"				\
    "\36INTERNAL"			\
    "\35BUCKET"				\
    "\33CACHE"				\
    "\32LIMIT"				\
    "\31CTORDTOR"			\
    "\30VTOSLAB"			\
    "\27HASH"				\
    "\26OFFPAGE"			\
    "\23SMR"				\
    "\22ROUNDROBIN"			\
    "\21FIRSTTOUCH"			\
    "\20PCPU"				\
    "\17NODUMP"				\
    "\16CACHESPREAD"			\
    "\14MAXBUCKET"			\
    "\13NOBUCKET"			\
    "\12SECONDARY"			\
    "\11NOTPAGE"			\
    "\10VM"				\
    "\7MTXCLASS"			\
    "\6NOFREE"				\
    "\5MALLOC"				\
    "\4NOTOUCH"				\
    "\3CONTIG"				\
    "\2ZINIT"

/*
 * Hash table for freed address -> slab translation.
 *
 * Only zones with memory not touchable by the allocator use the
 * hash table.  Otherwise slabs are found with vtoslab().
 */
#define UMA_HASH_SIZE_INIT	32		

#define UMA_HASH(h, s) ((((uintptr_t)s) >> UMA_SLAB_SHIFT) & (h)->uh_hashmask)

#define UMA_HASH_INSERT(h, s, mem)					\
	LIST_INSERT_HEAD(&(h)->uh_slab_hash[UMA_HASH((h),		\
	    (mem))], slab_tohashslab(s), uhs_hlink)

#define UMA_HASH_REMOVE(h, s)						\
	LIST_REMOVE(slab_tohashslab(s), uhs_hlink)

LIST_HEAD(slabhashhead, uma_hash_slab);

struct uma_hash {
	struct slabhashhead	*uh_slab_hash;	/* Hash table for slabs */
	u_int		uh_hashsize;	/* Current size of the hash table */
	u_int		uh_hashmask;	/* Mask used during hashing */
};

/*
 * Align field or structure to cache 'sector' in intel terminology.  This
 * is more efficient with adjacent line prefetch.
 */
#if defined(__amd64__) || defined(__powerpc64__)
#define UMA_SUPER_ALIGN	(CACHE_LINE_SIZE * 2)
#else
#define UMA_SUPER_ALIGN	CACHE_LINE_SIZE
#endif

#define	UMA_ALIGN	__aligned(UMA_SUPER_ALIGN)

/*
 * The uma_bucket structure is used to queue and manage buckets divorced
 * from per-cpu caches.  They are loaded into uma_cache_bucket structures
 * for use.
 */
struct uma_bucket {
	STAILQ_ENTRY(uma_bucket)	ub_link; /* Link into the zone */
	int16_t		ub_cnt;			/* Count of items in bucket. */
	int16_t		ub_entries;		/* Max items. */
	smr_seq_t	ub_seq;			/* SMR sequence number. */
	void		*ub_bucket[];		/* actual allocation storage */
};

typedef struct uma_bucket * uma_bucket_t;

/*
 * The uma_cache_bucket structure is statically allocated on each per-cpu
 * cache.  Its use reduces branches and cache misses in the fast path.
 */
struct uma_cache_bucket {
	uma_bucket_t	ucb_bucket;
	int16_t		ucb_cnt;
	int16_t		ucb_entries;
	uint32_t	ucb_spare;
};

typedef struct uma_cache_bucket * uma_cache_bucket_t;

/*
 * The uma_cache structure is allocated for each cpu for every zone
 * type.  This optimizes synchronization out of the allocator fast path.
 */
struct uma_cache {
	struct uma_cache_bucket	uc_freebucket;	/* Bucket we're freeing to */
	struct uma_cache_bucket	uc_allocbucket;	/* Bucket to allocate from */
	struct uma_cache_bucket	uc_crossbucket;	/* cross domain bucket */
	uint64_t		uc_allocs;	/* Count of allocations */
	uint64_t		uc_frees;	/* Count of frees */
} UMA_ALIGN;

typedef struct uma_cache * uma_cache_t;

LIST_HEAD(slabhead, uma_slab);

/*
 * The cache structure pads perfectly into 64 bytes so we use spare
 * bits from the embedded cache buckets to store information from the zone
 * and keep all fast-path allocations accessing a single per-cpu line.
 */
static inline void
cache_set_uz_flags(uma_cache_t cache, uint32_t flags)
{

	cache->uc_freebucket.ucb_spare = flags;
}

static inline void
cache_set_uz_size(uma_cache_t cache, uint32_t size)
{

	cache->uc_allocbucket.ucb_spare = size;
}

static inline uint32_t
cache_uz_flags(uma_cache_t cache)
{

	return (cache->uc_freebucket.ucb_spare);
}

static inline uint32_t
cache_uz_size(uma_cache_t cache)
{

	return (cache->uc_allocbucket.ucb_spare);
}

/*
 * Per-domain slab lists.  Embedded in the kegs.
 */
struct uma_domain {
	struct mtx_padalign ud_lock;	/* Lock for the domain lists. */
	struct slabhead	ud_part_slab;	/* partially allocated slabs */
	struct slabhead	ud_free_slab;	/* completely unallocated slabs */
	struct slabhead ud_full_slab;	/* fully allocated slabs */
	uint32_t	ud_pages;	/* Total page count */
	uint32_t	ud_free_items;	/* Count of items free in all slabs */
	uint32_t	ud_free_slabs;	/* Count of free slabs */
} __aligned(CACHE_LINE_SIZE);

typedef struct uma_domain * uma_domain_t;

/*
 * Keg management structure
 *
 * TODO: Optimize for cache line size
 *
 */
struct uma_keg {
	struct uma_hash	uk_hash;
	LIST_HEAD(,uma_zone)	uk_zones;	/* Keg's zones */

	struct domainset_ref uk_dr;	/* Domain selection policy. */
	uint32_t	uk_align;	/* Alignment mask */
	uint32_t	uk_reserve;	/* Number of reserved items. */
	uint32_t	uk_size;	/* Requested size of each item */
	uint32_t	uk_rsize;	/* Real size of each item */

	uma_init	uk_init;	/* Keg's init routine */
	uma_fini	uk_fini;	/* Keg's fini routine */
	uma_alloc	uk_allocf;	/* Allocation function */
	uma_free	uk_freef;	/* Free routine */

	u_long		uk_offset;	/* Next free offset from base KVA */
	vm_offset_t	uk_kva;		/* Zone base KVA */

	uint32_t	uk_pgoff;	/* Offset to uma_slab struct */
	uint16_t	uk_ppera;	/* pages per allocation from backend */
	uint16_t	uk_ipers;	/* Items per slab */
	uint32_t	uk_flags;	/* Internal flags */

	/* Least used fields go to the last cache line. */
	const char	*uk_name;		/* Name of creating zone. */
	LIST_ENTRY(uma_keg)	uk_link;	/* List of all kegs */

	/* Must be last, variable sized. */
	struct uma_domain	uk_domain[];	/* Keg's slab lists. */
};
typedef struct uma_keg	* uma_keg_t;

/*
 * Free bits per-slab.
 */
#define	SLAB_MAX_SETSIZE	(PAGE_SIZE / UMA_SMALLEST_UNIT)
#define	SLAB_MIN_SETSIZE	_BITSET_BITS
BITSET_DEFINE(noslabbits, 0);

/*
 * The slab structure manages a single contiguous allocation from backing
 * store and subdivides it into individually allocatable items.
 */
struct uma_slab {
	LIST_ENTRY(uma_slab)	us_link;	/* slabs in zone */
	uint16_t	us_freecount;		/* How many are free? */
	uint8_t		us_flags;		/* Page flags see uma.h */
	uint8_t		us_domain;		/* Backing NUMA domain. */
	struct noslabbits us_free;		/* Free bitmask, flexible. */
};
_Static_assert(sizeof(struct uma_slab) == __offsetof(struct uma_slab, us_free),
    "us_free field must be last");
_Static_assert(MAXMEMDOM < 255,
    "us_domain field is not wide enough");

typedef struct uma_slab * uma_slab_t;

/*
 * Slab structure with a full sized bitset and hash link for both
 * HASH and OFFPAGE zones.
 */
struct uma_hash_slab {
	LIST_ENTRY(uma_hash_slab) uhs_hlink;	/* Link for hash table */
	uint8_t			*uhs_data;	/* First item */
	struct uma_slab		uhs_slab;	/* Must be last. */
};

typedef struct uma_hash_slab * uma_hash_slab_t;

static inline uma_hash_slab_t
slab_tohashslab(uma_slab_t slab)
{

	return (__containerof(slab, struct uma_hash_slab, uhs_slab));
}

static inline void *
slab_data(uma_slab_t slab, uma_keg_t keg)
{

	if ((keg->uk_flags & UMA_ZFLAG_OFFPAGE) == 0)
		return ((void *)((uintptr_t)slab - keg->uk_pgoff));
	else
		return (slab_tohashslab(slab)->uhs_data);
}

static inline void *
slab_item(uma_slab_t slab, uma_keg_t keg, int index)
{
	uintptr_t data;

	data = (uintptr_t)slab_data(slab, keg);
	return ((void *)(data + keg->uk_rsize * index));
}

static inline int
slab_item_index(uma_slab_t slab, uma_keg_t keg, void *item)
{
	uintptr_t data;

	data = (uintptr_t)slab_data(slab, keg);
	return (((uintptr_t)item - data) / keg->uk_rsize);
}

STAILQ_HEAD(uma_bucketlist, uma_bucket);

struct uma_zone_domain {
	struct uma_bucketlist uzd_buckets; /* full buckets */
	uma_bucket_t	uzd_cross;	/* Fills from cross buckets. */
	long		uzd_nitems;	/* total item count */
	long		uzd_imax;	/* maximum item count this period */
	long		uzd_imin;	/* minimum item count this period */
	long		uzd_bimin;	/* Minimum item count this batch. */
	long		uzd_wss;	/* working set size estimate */
	long		uzd_limin;	/* Longtime minimum item count. */
	u_int		uzd_timin;	/* Time since uzd_limin == 0. */
	smr_seq_t	uzd_seq;	/* Lowest queued seq. */
	struct mtx	uzd_lock;	/* Lock for the domain */
} __aligned(CACHE_LINE_SIZE);

typedef struct uma_zone_domain * uma_zone_domain_t;

/*
 * Zone structure - per memory type.
 */
struct uma_zone {
	/* Offset 0, used in alloc/free fast/medium fast path and const. */
	uint32_t	uz_flags;	/* Flags inherited from kegs */
	uint32_t	uz_size;	/* Size inherited from kegs */
	uma_ctor	uz_ctor;	/* Constructor for each allocation */
	uma_dtor	uz_dtor;	/* Destructor */
	smr_t		uz_smr;		/* Safe memory reclaim context. */
	uint64_t	uz_max_items;	/* Maximum number of items to alloc */
	uint64_t	uz_bucket_max;	/* Maximum bucket cache size */
	uint16_t	uz_bucket_size;	/* Number of items in full bucket */
	uint16_t	uz_bucket_size_max; /* Maximum number of bucket items */
	uint32_t	uz_sleepers;	/* Threads sleeping on limit */
	counter_u64_t	uz_xdomain;	/* Total number of cross-domain frees */

	/* Offset 64, used in bucket replenish. */
	uma_keg_t	uz_keg;		/* This zone's keg if !CACHE */
	uma_import	uz_import;	/* Import new memory to cache. */
	uma_release	uz_release;	/* Release memory from cache. */
	void		*uz_arg;	/* Import/release argument. */
	uma_init	uz_init;	/* Initializer for each item */
	uma_fini	uz_fini;	/* Finalizer for each item. */
	volatile uint64_t uz_items;	/* Total items count & sleepers */
	uint64_t	uz_sleeps;	/* Total number of alloc sleeps */

	/* Offset 128 Rare stats, misc read-only. */
	LIST_ENTRY(uma_zone) uz_link;	/* List of all zones in keg */
	counter_u64_t	uz_allocs;	/* Total number of allocations */
	counter_u64_t	uz_frees;	/* Total number of frees */
	counter_u64_t	uz_fails;	/* Total number of alloc failures */
	const char	*uz_name;	/* Text name of the zone */
	char		*uz_ctlname;	/* sysctl safe name string. */
	int		uz_namecnt;	/* duplicate name count. */
	uint16_t	uz_bucket_size_min; /* Min number of items in bucket */
	uint16_t	uz_reclaimers;	/* pending reclaim operations. */

	/* Offset 192, rare read-only. */
	struct sysctl_oid *uz_oid;	/* sysctl oid pointer. */
	const char	*uz_warning;	/* Warning to print on failure */
	struct timeval	uz_ratecheck;	/* Warnings rate-limiting */
	struct task	uz_maxaction;	/* Task to run when at limit */

	/* Offset 256. */
	struct mtx	uz_cross_lock;	/* Cross domain free lock */

	/*
	 * This HAS to be the last item because we adjust the zone size
	 * based on NCPU and then allocate the space for the zones.
	 */
	struct uma_cache	uz_cpu[]; /* Per cpu caches */

	/* domains follow here. */
};

/*
 * Macros for interpreting the uz_items field.  20 bits of sleeper count
 * and 44 bit of item count.
 */
#define	UZ_ITEMS_SLEEPER_SHIFT	44LL
#define	UZ_ITEMS_SLEEPERS_MAX	((1 << (64 - UZ_ITEMS_SLEEPER_SHIFT)) - 1)
#define	UZ_ITEMS_COUNT_MASK	((1LL << UZ_ITEMS_SLEEPER_SHIFT) - 1)
#define	UZ_ITEMS_COUNT(x)	((x) & UZ_ITEMS_COUNT_MASK)
#define	UZ_ITEMS_SLEEPERS(x)	((x) >> UZ_ITEMS_SLEEPER_SHIFT)
#define	UZ_ITEMS_SLEEPER	(1LL << UZ_ITEMS_SLEEPER_SHIFT)

#define	ZONE_ASSERT_COLD(z)						\
	KASSERT(uma_zone_get_allocs((z)) == 0,				\
	    ("zone %s initialization after use.", (z)->uz_name))

/* Domains are contiguous after the last CPU */
#define	ZDOM_GET(z, n)							\
	(&((uma_zone_domain_t)&(z)->uz_cpu[mp_maxid + 1])[n])

#undef	UMA_ALIGN

#ifdef _KERNEL
/* Internal prototypes */
static __inline uma_slab_t hash_sfind(struct uma_hash *hash, uint8_t *data);

/* Lock Macros */

#define	KEG_LOCKPTR(k, d)	(struct mtx *)&(k)->uk_domain[(d)].ud_lock
#define	KEG_LOCK_INIT(k, d, lc)						\
	do {								\
		if ((lc))						\
			mtx_init(KEG_LOCKPTR(k, d), (k)->uk_name,	\
			    (k)->uk_name, MTX_DEF | MTX_DUPOK);		\
		else							\
			mtx_init(KEG_LOCKPTR(k, d), (k)->uk_name,	\
			    "UMA zone", MTX_DEF | MTX_DUPOK);		\
	} while (0)

#define	KEG_LOCK_FINI(k, d)	mtx_destroy(KEG_LOCKPTR(k, d))
#define	KEG_LOCK(k, d)							\
	({ mtx_lock(KEG_LOCKPTR(k, d)); KEG_LOCKPTR(k, d); })
#define	KEG_UNLOCK(k, d)	mtx_unlock(KEG_LOCKPTR(k, d))
#define	KEG_LOCK_ASSERT(k, d)	mtx_assert(KEG_LOCKPTR(k, d), MA_OWNED)

#define	KEG_GET(zone, keg) do {					\
	(keg) = (zone)->uz_keg;					\
	KASSERT((void *)(keg) != NULL,				\
	    ("%s: Invalid zone %p type", __func__, (zone)));	\
	} while (0)

#define	KEG_ASSERT_COLD(k)						\
	KASSERT(uma_keg_get_allocs((k)) == 0,				\
	    ("keg %s initialization after use.", (k)->uk_name))

#define	ZDOM_LOCK_INIT(z, zdom, lc)					\
	do {								\
		if ((lc))						\
			mtx_init(&(zdom)->uzd_lock, (z)->uz_name,	\
			    (z)->uz_name, MTX_DEF | MTX_DUPOK);		\
		else							\
			mtx_init(&(zdom)->uzd_lock, (z)->uz_name,	\
			    "UMA zone", MTX_DEF | MTX_DUPOK);		\
	} while (0)
#define	ZDOM_LOCK_FINI(z)	mtx_destroy(&(z)->uzd_lock)
#define	ZDOM_LOCK_ASSERT(z)	mtx_assert(&(z)->uzd_lock, MA_OWNED)

#define	ZDOM_LOCK(z)	mtx_lock(&(z)->uzd_lock)
#define	ZDOM_OWNED(z)	(mtx_owner(&(z)->uzd_lock) != NULL)
#define	ZDOM_UNLOCK(z)	mtx_unlock(&(z)->uzd_lock)

#define	ZONE_LOCK(z)	ZDOM_LOCK(ZDOM_GET((z), 0))
#define	ZONE_UNLOCK(z)	ZDOM_UNLOCK(ZDOM_GET((z), 0))
#define	ZONE_LOCKPTR(z)	(&ZDOM_GET((z), 0)->uzd_lock)

#define	ZONE_CROSS_LOCK_INIT(z)					\
	mtx_init(&(z)->uz_cross_lock, "UMA Cross", NULL, MTX_DEF)
#define	ZONE_CROSS_LOCK(z)	mtx_lock(&(z)->uz_cross_lock)
#define	ZONE_CROSS_UNLOCK(z)	mtx_unlock(&(z)->uz_cross_lock)
#define	ZONE_CROSS_LOCK_FINI(z)	mtx_destroy(&(z)->uz_cross_lock)

/*
 * Find a slab within a hash table.  This is used for OFFPAGE zones to lookup
 * the slab structure.
 *
 * Arguments:
 *	hash  The hash table to search.
 *	data  The base page of the item.
 *
 * Returns:
 *	A pointer to a slab if successful, else NULL.
 */
static __inline uma_slab_t
hash_sfind(struct uma_hash *hash, uint8_t *data)
{
        uma_hash_slab_t slab;
        u_int hval;

        hval = UMA_HASH(hash, data);

        LIST_FOREACH(slab, &hash->uh_slab_hash[hval], uhs_hlink) {
                if ((uint8_t *)slab->uhs_data == data)
                        return (&slab->uhs_slab);
        }
        return (NULL);
}

static __inline uma_slab_t
vtoslab(vm_offset_t va)
{
	vm_page_t p;

	p = PHYS_TO_VM_PAGE(pmap_kextract(va));
	return (p->plinks.uma.slab);
}

static __inline void
vtozoneslab(vm_offset_t va, uma_zone_t *zone, uma_slab_t *slab)
{
	vm_page_t p;

	p = PHYS_TO_VM_PAGE(pmap_kextract(va));
	*slab = p->plinks.uma.slab;
	*zone = p->plinks.uma.zone;
}

static __inline void
vsetzoneslab(vm_offset_t va, uma_zone_t zone, uma_slab_t slab)
{
	vm_page_t p;

	p = PHYS_TO_VM_PAGE(pmap_kextract(va));
	p->plinks.uma.slab = slab;
	p->plinks.uma.zone = zone;
}

extern unsigned long uma_kmem_limit;
extern unsigned long uma_kmem_total;

/* Adjust bytes under management by UMA. */
static inline void
uma_total_dec(unsigned long size)
{

	atomic_subtract_long(&uma_kmem_total, size);
}

static inline void
uma_total_inc(unsigned long size)
{

	if (atomic_fetchadd_long(&uma_kmem_total, size) > uma_kmem_limit)
		uma_reclaim_wakeup();
}

/*
 * The following two functions may be defined by architecture specific code
 * if they can provide more efficient allocation functions.  This is useful
 * for using direct mapped addresses.
 */
void *uma_small_alloc(uma_zone_t zone, vm_size_t bytes, int domain,
    uint8_t *pflag, int wait);
void uma_small_free(void *mem, vm_size_t size, uint8_t flags);

/* Set a global soft limit on UMA managed memory. */
void uma_set_limit(unsigned long limit);

#endif /* _KERNEL */

#endif /* VM_UMA_INT_H */