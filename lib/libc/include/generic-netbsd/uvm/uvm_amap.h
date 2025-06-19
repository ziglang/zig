/*	$NetBSD: uvm_amap.h,v 1.41 2020/03/20 19:08:54 ad Exp $	*/

/*
 * Copyright (c) 1997 Charles D. Cranor and Washington University.
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

#ifndef _UVM_UVM_AMAP_H_
#define _UVM_UVM_AMAP_H_

/*
 * uvm_amap.h: general amap interface and amap implementation-specific info
 */

/*
 * an amap structure contains pointers to a set of anons that are
 * mapped together in virtual memory (an anon is a single page of
 * anonymous virtual memory -- see uvm_anon.h).  in uvm we hide the
 * details of the implementation of amaps behind a general amap
 * interface.  this allows us to change the amap implementation
 * without having to touch the rest of the code.  this file is divided
 * into two parts: the definition of the uvm amap interface and the
 * amap implementation-specific definitions.
 */

#ifdef _KERNEL

/*
 * part 1: amap interface
 */

void	uvm_amap_init(void);

/*
 * forward definition of vm_amap structure.  only amap
 * implementation-specific code should directly access the fields of
 * this structure.
 */

struct vm_amap;


/*
 * prototypes for the amap interface
 */

void		amap_add 	/* add an anon to an amap */
			(struct vm_aref *, vaddr_t,
			 struct vm_anon *, bool);
struct vm_amap	*amap_alloc	/* allocate a new amap */
			(vaddr_t, vaddr_t, int);
void		amap_copy	/* clear amap needs-copy flag */
			(struct vm_map *, struct vm_map_entry *, int,
			 vaddr_t, vaddr_t);
void		amap_cow_now	/* resolve all COW faults now */
			(struct vm_map *, struct vm_map_entry *);
int		amap_extend	/* make amap larger */
			(struct vm_map_entry *, vsize_t, int);
int		amap_flags	/* get amap's flags */
			(struct vm_amap *);
void		amap_free	/* free amap */
			(struct vm_amap *);
void		amap_lock	/* lock amap */
			(struct vm_amap *);
struct vm_anon	*amap_lookup	/* lookup an anon @ offset in amap */
			(struct vm_aref *, vaddr_t);
void		amap_lookups	/* lookup multiple anons */
			(struct vm_aref *, vaddr_t,
			 struct vm_anon **, int);
void		amap_ref	/* add a reference to an amap */
			(struct vm_amap *, vaddr_t, vsize_t, int);
int		amap_refs	/* get number of references of amap */
			(struct vm_amap *);
void		amap_share_protect /* protect pages in a shared amap */
			(struct vm_map_entry *, vm_prot_t);
void		amap_splitref	/* split reference to amap into two */
			(struct vm_aref *, struct vm_aref *, vaddr_t);
void		amap_unadd	/* remove an anon from an amap */
			(struct vm_aref *, vaddr_t);
void		amap_unlock	/* unlock amap */
			(struct vm_amap *);
void		amap_unref	/* drop reference to an amap */
			(struct vm_amap *, vaddr_t, vsize_t, bool);
void		amap_wipeout	/* remove all anons from amap */
			(struct vm_amap *);
bool		amap_swap_off
			(int, int);

/*
 * amap flag values
 */

#define AMAP_SHARED	0x1	/* amap is shared */
#define AMAP_REFALL	0x2	/* amap_ref: reference entire amap */
#define AMAP_SWAPOFF	0x4	/* amap_swap_off() is in progress */

/*
 * amap_copy flags
 */

#define	AMAP_COPY_NOWAIT	0x02	/* not allowed to sleep */
#define	AMAP_COPY_NOCHUNK	0x04	/* not allowed to chunk */
#define	AMAP_COPY_NOMERGE	0x08	/* not allowed to merge */

/*
 * amap_extend flags
 */
#define AMAP_EXTEND_BACKWARDS	0x00	/* add "size" to start of map */
#define AMAP_EXTEND_FORWARDS	0x01	/* add "size" to end of map */
#define AMAP_EXTEND_NOWAIT	0x02	/* not allowed to sleep */

#endif /* _KERNEL */

/**********************************************************************/

/*
 * part 2: amap implementation-specific info
 */

/*
 * we currently provide an array-based amap implementation.  in this
 * implementation we provide the option of tracking split references
 * so that we don't lose track of references during partial unmaps
 * ... this is enabled with the "UVM_AMAP_PPREF" define.
 */

#define UVM_AMAP_PPREF		/* track partial references */

/*
 * here is the definition of the vm_amap structure for this implementation.
 */

struct vm_amap {
	krwlock_t *am_lock;	/* lock [locks all vm_amap fields] */
	int am_ref;		/* reference count */
	int am_flags;		/* flags */
	int am_maxslot;		/* max # of slots allocated */
	int am_nslot;		/* # of slots currently in map ( <= maxslot) */
	int am_nused;		/* # of slots currently in use */
	int *am_slots;		/* contig array of active slots */
	int *am_bckptr;		/* back pointer array to am_slots */
	struct vm_anon **am_anon; /* array of anonymous pages */
#ifdef UVM_AMAP_PPREF
	int *am_ppref;		/* per page reference count (if !NULL) */
#endif
	LIST_ENTRY(vm_amap) am_list;
};

/*
 * note that am_slots, am_bckptr, and am_anon are arrays.   this allows
 * fast lookup of pages based on their virual address at the expense of
 * some extra memory.   in the future we should be smarter about memory
 * usage and fall back to a non-array based implementation on systems
 * that are short of memory (XXXCDC).
 *
 * the entries in the array are called slots... for example an amap that
 * covers four pages of virtual memory is said to have four slots.   here
 * is an example of the array usage for a four slot amap.   note that only
 * slots one and three have anons assigned to them.  "D/C" means that we
 * "don't care" about the value.
 *
 *            0     1      2     3
 * am_anon:   NULL, anon0, NULL, anon1		(actual pointers to anons)
 * am_bckptr: D/C,  1,     D/C,  0		(points to am_slots entry)
 *
 * am_slots:  3, 1, D/C, D/C    		(says slots 3 and 1 are in use)
 *
 * note that am_bckptr is D/C if the slot in am_anon is set to NULL.
 * to find the entry in am_slots for an anon, look at am_bckptr[slot],
 * thus the entry for slot 3 in am_slots[] is at am_slots[am_bckptr[3]].
 * in general, if am_anon[X] is non-NULL, then the following must be
 * true: am_slots[am_bckptr[X]] == X
 *
 * note that am_slots is always contig-packed.
 */

/*
 * defines for handling of large, sparse amaps:
 *
 * one of the problems of array-based amaps is that if you allocate a
 * large, sparsely-used area of virtual memory you end up allocating
 * large arrays that, for the most part, don't get used.  this is a
 * problem for BSD in that the kernel likes to make these types of
 * allocations to "reserve" memory for possible future use.
 *
 * for example, the kernel allocates (reserves) a large chunk of user
 * VM for possible stack growth.  most of the time only a page or two
 * of this VM is actually used.  since the stack is anonymous memory
 * it makes sense for it to live in an amap, but if we allocated an
 * amap for the entire stack range we could end up wasting a large
 * amount of allocated KVM.
 *
 * for example, on the i386 at boot time we allocate two amaps for the stack
 * of /sbin/init:
 *  1. a 7680 slot amap at protection 0 (reserve space for stack)
 *  2. a 512 slot amap at protection 7 (top of stack)
 *
 * most of the array allocated for the amaps for this is never used.
 * the amap interface provides a way for us to avoid this problem by
 * allowing amap_copy() to break larger amaps up into smaller sized
 * chunks (controlled by the "canchunk" option).   we use this feature
 * to reduce our memory usage with the BSD stack management.  if we
 * are asked to create an amap with more than UVM_AMAP_LARGE slots in it,
 * we attempt to break it up into a UVM_AMAP_CHUNK sized amap if the
 * "canchunk" flag is set.
 *
 * so, in the i386 example, the 7680 slot area is never referenced so
 * nothing gets allocated (amap_copy is never called because the protection
 * is zero).   the 512 slot area for the top of the stack is referenced.
 * the chunking code breaks it up into 16 slot chunks (hopefully a single
 * 16 slot chunk is enough to handle the whole stack).
 */

#define UVM_AMAP_LARGE	256	/* # of slots in "large" amap */
#define UVM_AMAP_CHUNK	16	/* # of slots to chunk large amaps in */

#ifdef _KERNEL

/*
 * macros
 */

/* AMAP_B2SLOT: convert byte offset to slot */
#define AMAP_B2SLOT(S,B) {						\
	KASSERT(((B) & (PAGE_SIZE - 1)) == 0);				\
	(S) = (B) >> PAGE_SHIFT;					\
}

/*
 * lock/unlock/refs/flags macros
 */

#define amap_flags(AMAP)	((AMAP)->am_flags)
#define amap_lock(AMAP, OP)	rw_enter((AMAP)->am_lock, (OP))
#define amap_lock_try(AMAP, OP)	rw_tryenter((AMAP)->am_lock, (OP))
#define amap_refs(AMAP)		((AMAP)->am_ref)
#define amap_unlock(AMAP)	rw_exit((AMAP)->am_lock)

/*
 * if we enable PPREF, then we have a couple of extra functions that
 * we need to prototype here...
 */

#ifdef UVM_AMAP_PPREF

#define PPREF_NONE ((int *) -1)	/* not using ppref */

void		amap_pp_adjref		/* adjust references */
			(struct vm_amap *, int, vsize_t, int);
void		amap_pp_establish	/* establish ppref */
			(struct vm_amap *, vaddr_t);
void		amap_wiperange		/* wipe part of an amap */
			(struct vm_amap *, int, int);
#endif	/* UVM_AMAP_PPREF */

#endif /* _KERNEL */

#endif /* _UVM_UVM_AMAP_H_ */