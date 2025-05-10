/*-
 * SPDX-License-Identifier: (BSD-3-Clause AND MIT-CMU)
 *
 * Copyright (c) 1991, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * The Mach Operating System project at Carnegie-Mellon University.
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
 *	from: @(#)vm_object.h	8.3 (Berkeley) 1/12/94
 *
 *
 * Copyright (c) 1987, 1990 Carnegie-Mellon University.
 * All rights reserved.
 *
 * Authors: Avadis Tevanian, Jr., Michael Wayne Young
 *
 * Permission to use, copy, modify and distribute this software and
 * its documentation is hereby granted, provided that both the copyright
 * notice and this permission notice appear in all copies of the
 * software, derivative works or modified versions, and any portions
 * thereof, and that both notices appear in supporting documentation.
 *
 * CARNEGIE MELLON ALLOWS FREE USE OF THIS SOFTWARE IN ITS "AS IS"
 * CONDITION.  CARNEGIE MELLON DISCLAIMS ANY LIABILITY OF ANY KIND
 * FOR ANY DAMAGES WHATSOEVER RESULTING FROM THE USE OF THIS SOFTWARE.
 *
 * Carnegie Mellon requests users of this software to return to
 *
 *  Software Distribution Coordinator  or  Software.Distribution@CS.CMU.EDU
 *  School of Computer Science
 *  Carnegie Mellon University
 *  Pittsburgh PA 15213-3890
 *
 * any improvements or extensions that they make and grant Carnegie the
 * rights to redistribute these changes.
 */

/*
 *	Virtual memory object module definitions.
 */

#ifndef	_VM_OBJECT_
#define	_VM_OBJECT_

#include <sys/queue.h>
#include <sys/_blockcount.h>
#include <sys/_lock.h>
#include <sys/_mutex.h>
#include <sys/_pctrie.h>
#include <sys/_rwlock.h>
#include <sys/_domainset.h>

#include <vm/_vm_radix.h>

/*
 *	Types defined:
 *
 *	vm_object_t		Virtual memory object.
 *
 * List of locks
 *	(a)	atomic
 *	(c)	const until freed
 *	(o)	per-object lock 
 *	(f)	free pages queue mutex
 *
 */

#ifndef VM_PAGE_HAVE_PGLIST
TAILQ_HEAD(pglist, vm_page);
#define VM_PAGE_HAVE_PGLIST
#endif

struct vm_object {
	struct rwlock lock;
	TAILQ_ENTRY(vm_object) object_list; /* list of all objects */
	LIST_HEAD(, vm_object) shadow_head; /* objects that this is a shadow for */
	LIST_ENTRY(vm_object) shadow_list; /* chain of shadow objects */
	struct pglist memq;		/* list of resident pages */
	struct vm_radix rtree;		/* root of the resident page radix trie*/
	vm_pindex_t size;		/* Object size */
	struct domainset_ref domain;	/* NUMA policy. */
	volatile int generation;	/* generation ID */
	int cleangeneration;		/* Generation at clean time */
	volatile u_int ref_count;	/* How many refs?? */
	int shadow_count;		/* how many objects that this is a shadow for */
	vm_memattr_t memattr;		/* default memory attribute for pages */
	objtype_t type;			/* type of pager */
	u_short pg_color;		/* (c) color of first page in obj */
	u_int flags;			/* see below */
	blockcount_t paging_in_progress; /* (a) Paging (in or out) so don't collapse or destroy */
	blockcount_t busy;		/* (a) object is busy, disallow page busy. */
	int resident_page_count;	/* number of resident pages */
	struct vm_object *backing_object; /* object that I'm a shadow of */
	vm_ooffset_t backing_object_offset;/* Offset in backing object */
	TAILQ_ENTRY(vm_object) pager_object_list; /* list of all objects of this pager type */
	LIST_HEAD(, vm_reserv) rvq;	/* list of reservations */
	void *handle;
	union {
		/*
		 * VNode pager
		 *
		 *	vnp_size - current size of file
		 */
		struct {
			off_t vnp_size;
			vm_ooffset_t writemappings;
		} vnp;

		/*
		 * Device pager
		 *
		 *	devp_pglist - list of allocated pages
		 */
		struct {
			TAILQ_HEAD(, vm_page) devp_pglist;
			const struct cdev_pager_ops *ops;
			void *handle;
		} devp;

		/*
		 * SG pager
		 *
		 *	sgp_pglist - list of allocated pages
		 */
		struct {
			TAILQ_HEAD(, vm_page) sgp_pglist;
		} sgp;

		/*
		 * Swap pager
		 *
		 *	swp_priv - pager-private.
		 *	swp_blks - pc-trie of the allocated swap blocks.
		 *	writemappings - count of bytes mapped for write
		 *
		 */
		struct {
			void *swp_priv;
			struct pctrie swp_blks;
			vm_ooffset_t writemappings;
		} swp;

		/*
		 * Phys pager
		 */
		struct {
			const struct phys_pager_ops *ops;
			union {
				void *data_ptr;
				uintptr_t data_val;
			};
			void *phys_priv;
		} phys;
	} un_pager;
	struct ucred *cred;
	vm_ooffset_t charge;
	void *umtx_data;
};

/*
 * Flags
 */
#define	OBJ_FICTITIOUS	0x00000001	/* (c) contains fictitious pages */
#define	OBJ_UNMANAGED	0x00000002	/* (c) contains unmanaged pages */
#define	OBJ_POPULATE	0x00000004	/* pager implements populate() */
#define	OBJ_DEAD	0x00000008	/* dead objects (during rundown) */
#define	OBJ_ANON	0x00000010	/* (c) contains anonymous memory */
#define	OBJ_UMTXDEAD	0x00000020	/* umtx pshared was terminated */
#define	OBJ_SIZEVNLOCK	0x00000040	/* lock vnode to check obj size */
#define	OBJ_PG_DTOR	0x00000080	/* do not reset object, leave that
					   for dtor */
#define	OBJ_SHADOWLIST	0x00000100	/* Object is on the shadow list. */
#define	OBJ_SWAP	0x00000200	/* object swaps, type will be OBJT_SWAP
					   or dynamically registered */
#define	OBJ_SPLIT	0x00000400	/* object is being split */
#define	OBJ_COLLAPSING	0x00000800	/* Parent of collapse. */
#define	OBJ_COLORED	0x00001000	/* pg_color is defined */
#define	OBJ_ONEMAPPING	0x00002000	/* One USE (a single, non-forked)
					   mapping flag */
#define	OBJ_PAGERPRIV1	0x00004000	/* Pager private */
#define	OBJ_PAGERPRIV2	0x00008000	/* Pager private */
#define	OBJ_SYSVSHM	0x00010000	/* SysV SHM */
#define	OBJ_POSIXSHM	0x00020000	/* Posix SHM */
#define	OBJ_CDEVH	0x00040000	/* OBJT_DEVICE handle is cdev */

/*
 * Helpers to perform conversion between vm_object page indexes and offsets.
 * IDX_TO_OFF() converts an index into an offset.
 * OFF_TO_IDX() converts an offset into an index.
 * OBJ_MAX_SIZE specifies the maximum page index corresponding to the
 *   maximum unsigned offset.
 */
#define	IDX_TO_OFF(idx) (((vm_ooffset_t)(idx)) << PAGE_SHIFT)
#define	OFF_TO_IDX(off) ((vm_pindex_t)(((vm_ooffset_t)(off)) >> PAGE_SHIFT))
#define	OBJ_MAX_SIZE	(OFF_TO_IDX(UINT64_MAX) + 1)

#ifdef	_KERNEL

#define OBJPC_SYNC	0x1			/* sync I/O */
#define OBJPC_INVAL	0x2			/* invalidate */
#define OBJPC_NOSYNC	0x4			/* skip if PGA_NOSYNC */

/*
 * The following options are supported by vm_object_page_remove().
 */
#define	OBJPR_CLEANONLY	0x1		/* Don't remove dirty pages. */
#define	OBJPR_NOTMAPPED	0x2		/* Don't unmap pages. */
#define	OBJPR_VALIDONLY	0x4		/* Ignore invalid pages. */

TAILQ_HEAD(object_q, vm_object);

extern struct object_q vm_object_list;	/* list of allocated objects */
extern struct mtx vm_object_list_mtx;	/* lock for object list and count */

extern struct vm_object kernel_object_store;

/* kernel and kmem are aliased for backwards KPI compat. */
#define	kernel_object	(&kernel_object_store)
#define	kmem_object	(&kernel_object_store)

#define	VM_OBJECT_ASSERT_LOCKED(object)					\
	rw_assert(&(object)->lock, RA_LOCKED)
#define	VM_OBJECT_ASSERT_RLOCKED(object)				\
	rw_assert(&(object)->lock, RA_RLOCKED)
#define	VM_OBJECT_ASSERT_WLOCKED(object)				\
	rw_assert(&(object)->lock, RA_WLOCKED)
#define	VM_OBJECT_ASSERT_UNLOCKED(object)				\
	rw_assert(&(object)->lock, RA_UNLOCKED)
#define	VM_OBJECT_LOCK_DOWNGRADE(object)				\
	rw_downgrade(&(object)->lock)
#define	VM_OBJECT_RLOCK(object)						\
	rw_rlock(&(object)->lock)
#define	VM_OBJECT_RUNLOCK(object)					\
	rw_runlock(&(object)->lock)
#define	VM_OBJECT_SLEEP(object, wchan, pri, wmesg, timo)		\
	rw_sleep((wchan), &(object)->lock, (pri), (wmesg), (timo))
#define	VM_OBJECT_TRYRLOCK(object)					\
	rw_try_rlock(&(object)->lock)
#define	VM_OBJECT_TRYWLOCK(object)					\
	rw_try_wlock(&(object)->lock)
#define	VM_OBJECT_TRYUPGRADE(object)					\
	rw_try_upgrade(&(object)->lock)
#define	VM_OBJECT_WLOCK(object)						\
	rw_wlock(&(object)->lock)
#define	VM_OBJECT_WOWNED(object)					\
	rw_wowned(&(object)->lock)
#define	VM_OBJECT_WUNLOCK(object)					\
	rw_wunlock(&(object)->lock)
#define	VM_OBJECT_UNLOCK(object)					\
	rw_unlock(&(object)->lock)
#define	VM_OBJECT_DROP(object)						\
	lock_class_rw.lc_unlock(&(object)->lock.lock_object)
#define	VM_OBJECT_PICKUP(object, state)					\
	lock_class_rw.lc_lock(&(object)->lock.lock_object, (state))

#define	VM_OBJECT_ASSERT_PAGING(object)					\
	KASSERT(blockcount_read(&(object)->paging_in_progress) != 0,	\
	    ("vm_object %p is not paging", object))
#define	VM_OBJECT_ASSERT_REFERENCE(object)				\
	KASSERT((object)->reference_count != 0,				\
	    ("vm_object %p is not referenced", object))

struct vnode;

/*
 *	The object must be locked or thread private.
 */
static __inline void
vm_object_set_flag(vm_object_t object, u_int bits)
{

	object->flags |= bits;
}

/*
 *	Conditionally set the object's color, which (1) enables the allocation
 *	of physical memory reservations for anonymous objects and larger-than-
 *	superpage-sized named objects and (2) determines the first page offset
 *	within the object at which a reservation may be allocated.  In other
 *	words, the color determines the alignment of the object with respect
 *	to the largest superpage boundary.  When mapping named objects, like
 *	files or POSIX shared memory objects, the color should be set to zero
 *	before a virtual address is selected for the mapping.  In contrast,
 *	for anonymous objects, the color may be set after the virtual address
 *	is selected.
 *
 *	The object must be locked.
 */
static __inline void
vm_object_color(vm_object_t object, u_short color)
{

	if ((object->flags & OBJ_COLORED) == 0) {
		object->pg_color = color;
		vm_object_set_flag(object, OBJ_COLORED);
	}
}

static __inline bool
vm_object_reserv(vm_object_t object)
{

	if (object != NULL &&
	    (object->flags & (OBJ_COLORED | OBJ_FICTITIOUS)) == OBJ_COLORED) {
		return (true);
	}
	return (false);
}

void vm_object_clear_flag(vm_object_t object, u_short bits);
void vm_object_pip_add(vm_object_t object, short i);
void vm_object_pip_wakeup(vm_object_t object);
void vm_object_pip_wakeupn(vm_object_t object, short i);
void vm_object_pip_wait(vm_object_t object, const char *waitid);
void vm_object_pip_wait_unlocked(vm_object_t object, const char *waitid);

void vm_object_busy(vm_object_t object);
void vm_object_unbusy(vm_object_t object);
void vm_object_busy_wait(vm_object_t object, const char *wmesg);

static inline bool
vm_object_busied(vm_object_t object)
{

	return (blockcount_read(&object->busy) != 0);
}
#define	VM_OBJECT_ASSERT_BUSY(object)	MPASS(vm_object_busied((object)))

void umtx_shm_object_init(vm_object_t object);
void umtx_shm_object_terminated(vm_object_t object);
extern int umtx_shm_vnobj_persistent;

vm_object_t vm_object_allocate (objtype_t, vm_pindex_t);
vm_object_t vm_object_allocate_anon(vm_pindex_t, vm_object_t, struct ucred *,
   vm_size_t);
vm_object_t vm_object_allocate_dyn(objtype_t, vm_pindex_t, u_short);
boolean_t vm_object_coalesce(vm_object_t, vm_ooffset_t, vm_size_t, vm_size_t,
   boolean_t);
void vm_object_collapse (vm_object_t);
void vm_object_deallocate (vm_object_t);
void vm_object_destroy (vm_object_t);
void vm_object_terminate (vm_object_t);
void vm_object_set_writeable_dirty (vm_object_t);
void vm_object_set_writeable_dirty_(vm_object_t object);
bool vm_object_mightbedirty(vm_object_t object);
bool vm_object_mightbedirty_(vm_object_t object);
void vm_object_init (void);
int  vm_object_kvme_type(vm_object_t object, struct vnode **vpp);
void vm_object_madvise(vm_object_t, vm_pindex_t, vm_pindex_t, int);
boolean_t vm_object_page_clean(vm_object_t object, vm_ooffset_t start,
    vm_ooffset_t end, int flags);
void vm_object_page_noreuse(vm_object_t object, vm_pindex_t start,
    vm_pindex_t end);
void vm_object_page_remove(vm_object_t object, vm_pindex_t start,
    vm_pindex_t end, int options);
boolean_t vm_object_populate(vm_object_t, vm_pindex_t, vm_pindex_t);
void vm_object_print(long addr, boolean_t have_addr, long count, char *modif);
void vm_object_reference (vm_object_t);
void vm_object_reference_locked(vm_object_t);
int  vm_object_set_memattr(vm_object_t object, vm_memattr_t memattr);
void vm_object_shadow(vm_object_t *, vm_ooffset_t *, vm_size_t, struct ucred *,
    bool);
void vm_object_split(vm_map_entry_t);
boolean_t vm_object_sync(vm_object_t, vm_ooffset_t, vm_size_t, boolean_t,
    boolean_t);
void vm_object_unwire(vm_object_t object, vm_ooffset_t offset,
    vm_size_t length, uint8_t queue);
struct vnode *vm_object_vnode(vm_object_t object);
bool vm_object_is_active(vm_object_t obj);
#endif				/* _KERNEL */

#endif				/* _VM_OBJECT_ */