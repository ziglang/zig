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
 *	@(#)vm_map.h	8.9 (Berkeley) 5/17/95
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
 *	Virtual memory map module definitions.
 */
#ifndef	_VM_MAP_
#define	_VM_MAP_

#include <sys/lock.h>
#include <sys/sx.h>
#include <sys/_mutex.h>

/*
 *	Types defined:
 *
 *	vm_map_t		the high-level address map data structure.
 *	vm_map_entry_t		an entry in an address map.
 */

typedef u_char vm_flags_t;
typedef u_int vm_eflags_t;

/*
 *	Objects which live in maps may be either VM objects, or
 *	another map (called a "sharing map") which denotes read-write
 *	sharing with other maps.
 */
union vm_map_object {
	struct vm_object *vm_object;	/* object object */
	struct vm_map *sub_map;		/* belongs to another map */
};

/*
 *	Address map entries consist of start and end addresses,
 *	a VM object (or sharing map) and offset into that object,
 *	and user-exported inheritance and protection information.
 *	Also included is control information for virtual copy operations.
 *
 *	For stack gap map entries (MAP_ENTRY_GUARD | MAP_ENTRY_GROWS_DOWN
 *	or UP), the next_read member is reused as the stack_guard_page
 *	storage, and offset is the stack protection.
 */
struct vm_map_entry {
	struct vm_map_entry *left;	/* left child or previous entry */
	struct vm_map_entry *right;	/* right child or next entry */
	vm_offset_t start;		/* start address */
	vm_offset_t end;		/* end address */
	vm_offset_t next_read;		/* vaddr of the next sequential read */
	vm_size_t max_free;		/* max free space in subtree */
	union vm_map_object object;	/* object I point to */
	vm_ooffset_t offset;		/* offset into object */
	vm_eflags_t eflags;		/* map entry flags */
	vm_prot_t protection;		/* protection code */
	vm_prot_t max_protection;	/* maximum protection */
	vm_inherit_t inheritance;	/* inheritance */
	uint8_t read_ahead;		/* pages in the read-ahead window */
	int wired_count;		/* can be paged if = 0 */
	struct ucred *cred;		/* tmp storage for creator ref */
	struct thread *wiring_thread;
};

#define	MAP_ENTRY_NOSYNC		0x00000001
#define	MAP_ENTRY_IS_SUB_MAP		0x00000002
#define	MAP_ENTRY_COW			0x00000004
#define	MAP_ENTRY_NEEDS_COPY		0x00000008
#define	MAP_ENTRY_NOFAULT		0x00000010
#define	MAP_ENTRY_USER_WIRED		0x00000020

#define	MAP_ENTRY_BEHAV_NORMAL		0x00000000	/* default behavior */
#define	MAP_ENTRY_BEHAV_SEQUENTIAL	0x00000040	/* expect sequential
							   access */
#define	MAP_ENTRY_BEHAV_RANDOM		0x00000080	/* expect random
							   access */
#define	MAP_ENTRY_BEHAV_RESERVED	0x000000c0	/* future use */
#define	MAP_ENTRY_BEHAV_MASK		0x000000c0
#define	MAP_ENTRY_IN_TRANSITION		0x00000100	/* entry being
							   changed */
#define	MAP_ENTRY_NEEDS_WAKEUP		0x00000200	/* waiters in
							   transition */
#define	MAP_ENTRY_NOCOREDUMP		0x00000400	/* don't include in
							   a core */
#define	MAP_ENTRY_VN_EXEC		0x00000800	/* text vnode mapping */
#define	MAP_ENTRY_GROWS_DOWN		0x00001000	/* top-down stacks */
#define	MAP_ENTRY_GROWS_UP		0x00002000	/* bottom-up stacks */

#define	MAP_ENTRY_WIRE_SKIPPED		0x00004000
#define	MAP_ENTRY_WRITECNT		0x00008000	/* tracked writeable
							   mapping */
#define	MAP_ENTRY_GUARD			0x00010000
#define	MAP_ENTRY_STACK_GAP_DN		0x00020000
#define	MAP_ENTRY_STACK_GAP_UP		0x00040000
#define	MAP_ENTRY_HEADER		0x00080000

#define	MAP_ENTRY_SPLIT_BOUNDARY_MASK	0x00300000
#define	MAP_ENTRY_SPLIT_BOUNDARY_SHIFT	20
#define	MAP_ENTRY_SPLIT_BOUNDARY_INDEX(entry)			\
	(((entry)->eflags & MAP_ENTRY_SPLIT_BOUNDARY_MASK) >>	\
	    MAP_ENTRY_SPLIT_BOUNDARY_SHIFT)

#ifdef	_KERNEL
static __inline u_char
vm_map_entry_behavior(vm_map_entry_t entry)
{
	return (entry->eflags & MAP_ENTRY_BEHAV_MASK);
}

static __inline int
vm_map_entry_user_wired_count(vm_map_entry_t entry)
{
	if (entry->eflags & MAP_ENTRY_USER_WIRED)
		return (1);
	return (0);
}

static __inline int
vm_map_entry_system_wired_count(vm_map_entry_t entry)
{
	return (entry->wired_count - vm_map_entry_user_wired_count(entry));
}
#endif	/* _KERNEL */

/*
 *	A map is a set of map entries.  These map entries are
 *	organized as a threaded binary search tree.  The tree is
 *	ordered based upon the start and end addresses contained
 *	within each map entry.  The largest gap between an entry in a
 *	subtree and one of its neighbors is saved in the max_free
 *	field, and that field is updated when the tree is restructured.
 *
 *	Sleator and Tarjan's top-down splay algorithm is employed to
 *	control height imbalance in the binary search tree.
 *
 *	The map's min offset value is stored in map->header.end, and
 *	its max offset value is stored in map->header.start.  These
 *	values act as sentinels for any forward or backward address
 *	scan of the list.  The right and left fields of the map
 *	header point to the first and list map entries.  The map
 *	header has a special value for the eflags field,
 *	MAP_ENTRY_HEADER, that is set initially, is never changed,
 *	and prevents an eflags match of the header with any other map
 *	entry.
 *
 *	List of locks
 *	(c)	const until freed
 */
struct vm_map {
	struct vm_map_entry header;	/* List of entries */
	struct sx lock;			/* Lock for map data */
	struct mtx system_mtx;
	int nentries;			/* Number of entries */
	vm_size_t size;			/* virtual size */
	u_int timestamp;		/* Version number */
	u_char needs_wakeup;
	u_char system_map;		/* (c) Am I a system map? */
	vm_flags_t flags;		/* flags for this vm_map */
	vm_map_entry_t root;		/* Root of a binary search tree */
	pmap_t pmap;			/* (c) Physical map */
	vm_offset_t anon_loc;
	int busy;
#ifdef DIAGNOSTIC
	int nupdates;
#endif
};

/*
 * vm_flags_t values
 */
#define MAP_WIREFUTURE		0x01	/* wire all future pages */
#define	MAP_BUSY_WAKEUP		0x02	/* thread(s) waiting on busy state */
#define	MAP_IS_SUB_MAP		0x04	/* has parent */
#define	MAP_ASLR		0x08	/* enabled ASLR */
#define	MAP_ASLR_IGNSTART	0x10	/* ASLR ignores data segment */
#define	MAP_REPLENISH		0x20	/* kmapent zone needs to be refilled */
#define	MAP_WXORX		0x40	/* enforce W^X */
#define	MAP_ASLR_STACK		0x80	/* stack location is randomized */

#ifdef	_KERNEL
#if defined(KLD_MODULE) && !defined(KLD_TIED)
#define	vm_map_max(map)		vm_map_max_KBI((map))
#define	vm_map_min(map)		vm_map_min_KBI((map))
#define	vm_map_pmap(map)	vm_map_pmap_KBI((map))
#define	vm_map_range_valid(map, start, end)	\
	vm_map_range_valid_KBI((map), (start), (end))
#else
static __inline vm_offset_t
vm_map_max(const struct vm_map *map)
{

	return (map->header.start);
}

static __inline vm_offset_t
vm_map_min(const struct vm_map *map)
{

	return (map->header.end);
}

static __inline pmap_t
vm_map_pmap(vm_map_t map)
{
	return (map->pmap);
}

static __inline void
vm_map_modflags(vm_map_t map, vm_flags_t set, vm_flags_t clear)
{
	map->flags = (map->flags | set) & ~clear;
}

static inline bool
vm_map_range_valid(vm_map_t map, vm_offset_t start, vm_offset_t end)
{
	if (end < start)
		return (false);
	if (start < vm_map_min(map) || end > vm_map_max(map))
		return (false);
	return (true);
}

#endif	/* KLD_MODULE */
#endif	/* _KERNEL */

/*
 * Shareable process virtual address space.
 *
 * List of locks
 *	(c)	const until freed
 */
struct vmspace {
	struct vm_map vm_map;	/* VM address map */
	struct shmmap_state *vm_shm;	/* SYS5 shared memory private data XXX */
	segsz_t vm_swrss;	/* resident set size before last swap */
	segsz_t vm_tsize;	/* text size (pages) XXX */
	segsz_t vm_dsize;	/* data size (pages) XXX */
	segsz_t vm_ssize;	/* stack size (pages) */
	caddr_t vm_taddr;	/* (c) user virtual address of text */
	caddr_t vm_daddr;	/* (c) user virtual address of data */
	caddr_t vm_maxsaddr;	/* user VA at max stack growth */
	vm_offset_t vm_stacktop; /* top of the stack, may not be page-aligned */
	vm_offset_t vm_shp_base; /* shared page address */
	u_int vm_refcnt;	/* number of references */
	/*
	 * Keep the PMAP last, so that CPU-specific variations of that
	 * structure on a single architecture don't result in offset
	 * variations of the machine-independent fields in the vmspace.
	 */
	struct pmap vm_pmap;	/* private physical map */
};

#ifdef	_KERNEL
static __inline pmap_t
vmspace_pmap(struct vmspace *vmspace)
{
	return &vmspace->vm_pmap;
}
#endif	/* _KERNEL */

#ifdef	_KERNEL
/*
 *	Macros:		vm_map_lock, etc.
 *	Function:
 *		Perform locking on the data portion of a map.  Note that
 *		these macros mimic procedure calls returning void.  The
 *		semicolon is supplied by the user of these macros, not
 *		by the macros themselves.  The macros can safely be used
 *		as unbraced elements in a higher level statement.
 */

void _vm_map_lock(vm_map_t map, const char *file, int line);
void _vm_map_unlock(vm_map_t map, const char *file, int line);
int _vm_map_unlock_and_wait(vm_map_t map, int timo, const char *file, int line);
void _vm_map_lock_read(vm_map_t map, const char *file, int line);
void _vm_map_unlock_read(vm_map_t map, const char *file, int line);
int _vm_map_trylock(vm_map_t map, const char *file, int line);
int _vm_map_trylock_read(vm_map_t map, const char *file, int line);
int _vm_map_lock_upgrade(vm_map_t map, const char *file, int line);
void _vm_map_lock_downgrade(vm_map_t map, const char *file, int line);
int vm_map_locked(vm_map_t map);
void vm_map_wakeup(vm_map_t map);
void vm_map_busy(vm_map_t map);
void vm_map_unbusy(vm_map_t map);
void vm_map_wait_busy(vm_map_t map);
vm_offset_t vm_map_max_KBI(const struct vm_map *map);
vm_offset_t vm_map_min_KBI(const struct vm_map *map);
pmap_t vm_map_pmap_KBI(vm_map_t map);
bool vm_map_range_valid_KBI(vm_map_t map, vm_offset_t start, vm_offset_t end);

#define	vm_map_lock(map)	_vm_map_lock(map, LOCK_FILE, LOCK_LINE)
#define	vm_map_unlock(map)	_vm_map_unlock(map, LOCK_FILE, LOCK_LINE)
#define	vm_map_unlock_and_wait(map, timo)	\
			_vm_map_unlock_and_wait(map, timo, LOCK_FILE, LOCK_LINE)
#define	vm_map_lock_read(map)	_vm_map_lock_read(map, LOCK_FILE, LOCK_LINE)
#define	vm_map_unlock_read(map)	_vm_map_unlock_read(map, LOCK_FILE, LOCK_LINE)
#define	vm_map_trylock(map)	_vm_map_trylock(map, LOCK_FILE, LOCK_LINE)
#define	vm_map_trylock_read(map)	\
			_vm_map_trylock_read(map, LOCK_FILE, LOCK_LINE)
#define	vm_map_lock_upgrade(map)	\
			_vm_map_lock_upgrade(map, LOCK_FILE, LOCK_LINE)
#define	vm_map_lock_downgrade(map)	\
			_vm_map_lock_downgrade(map, LOCK_FILE, LOCK_LINE)

long vmspace_resident_count(struct vmspace *vmspace);
#endif	/* _KERNEL */

/*
 * Copy-on-write flags for vm_map operations
 */
#define	MAP_INHERIT_SHARE	0x00000001
#define	MAP_COPY_ON_WRITE	0x00000002
#define	MAP_NOFAULT		0x00000004
#define	MAP_PREFAULT		0x00000008
#define	MAP_PREFAULT_PARTIAL	0x00000010
#define	MAP_DISABLE_SYNCER	0x00000020
#define	MAP_CHECK_EXCL		0x00000040
#define	MAP_CREATE_GUARD	0x00000080
#define	MAP_DISABLE_COREDUMP	0x00000100
#define	MAP_PREFAULT_MADVISE	0x00000200    /* from (user) madvise request */
#define	MAP_WRITECOUNT		0x00000400
#define	MAP_REMAP		0x00000800
#define	MAP_STACK_GROWS_DOWN	0x00001000
#define	MAP_STACK_GROWS_UP	0x00002000
#define	MAP_ACC_CHARGED		0x00004000
#define	MAP_ACC_NO_CHARGE	0x00008000
#define	MAP_CREATE_STACK_GAP_UP	0x00010000
#define	MAP_CREATE_STACK_GAP_DN	0x00020000
#define	MAP_VN_EXEC		0x00040000
#define	MAP_SPLIT_BOUNDARY_MASK	0x00180000
#define	MAP_NO_HINT		0x00200000

#define	MAP_SPLIT_BOUNDARY_SHIFT 19

/*
 * vm_fault option flags
 */
#define	VM_FAULT_NORMAL	0x00	/* Nothing special */
#define	VM_FAULT_WIRE	0x01	/* Wire the mapped page */
#define	VM_FAULT_DIRTY	0x02	/* Dirty the page; use w/VM_PROT_COPY */
#define	VM_FAULT_NOFILL	0x04	/* Fail if the pager doesn't have a copy */

/*
 * Initially, mappings are slightly sequential.  The maximum window size must
 * account for the map entry's "read_ahead" field being defined as an uint8_t.
 */
#define	VM_FAULT_READ_AHEAD_MIN		7
#define	VM_FAULT_READ_AHEAD_INIT	15
#define	VM_FAULT_READ_AHEAD_MAX		min(atop(maxphys) - 1, UINT8_MAX)

/*
 * The following "find_space" options are supported by vm_map_find().
 *
 * For VMFS_ALIGNED_SPACE, the desired alignment is specified to
 * the macro argument as log base 2 of the desired alignment.
 */
#define	VMFS_NO_SPACE		0	/* don't find; use the given range */
#define	VMFS_ANY_SPACE		1	/* find a range with any alignment */
#define	VMFS_OPTIMAL_SPACE	2	/* find a range with optimal alignment*/
#define	VMFS_SUPER_SPACE	3	/* find a superpage-aligned range */
#define	VMFS_ALIGNED_SPACE(x)	((x) << 8) /* find a range with fixed alignment */

/*
 * vm_map_wire and vm_map_unwire option flags
 */
#define VM_MAP_WIRE_SYSTEM	0	/* wiring in a kernel map */
#define VM_MAP_WIRE_USER	1	/* wiring in a user map */

#define VM_MAP_WIRE_NOHOLES	0	/* region must not have holes */
#define VM_MAP_WIRE_HOLESOK	2	/* region may have holes */

#define VM_MAP_WIRE_WRITE	4	/* Validate writable. */

typedef int vm_map_entry_reader(void *token, vm_map_entry_t addr, 
    vm_map_entry_t dest);

#ifndef _KERNEL
/*
 * Find the successor of a map_entry, using a reader to dereference pointers.
 * '*clone' is a copy of a vm_map entry.  'reader' is used to copy a map entry
 * at some address into '*clone'.  Change *clone to a copy of the next map
 * entry, and return the address of that entry, or NULL if copying has failed.
 *
 * This function is made available to user-space code that needs to traverse
 * map entries.
 */
static inline vm_map_entry_t
vm_map_entry_read_succ(void *token, struct vm_map_entry *const clone,
    vm_map_entry_reader reader)
{
	vm_map_entry_t after, backup;
	vm_offset_t start;

	after = clone->right;
	start = clone->start;
	if (!reader(token, after, clone))
		return (NULL);
	backup = clone->left;
	if (!reader(token, backup, clone))
		return (NULL);
	if (clone->start > start) {
		do {
			after = backup;
			backup = clone->left;
			if (!reader(token, backup, clone))
				return (NULL);
		} while (clone->start != start);
	}
	if (!reader(token, after, clone))
		return (NULL);
	return (after);
}
#endif				/* ! _KERNEL */

#ifdef _KERNEL
boolean_t vm_map_check_protection (vm_map_t, vm_offset_t, vm_offset_t, vm_prot_t);
int vm_map_delete(vm_map_t, vm_offset_t, vm_offset_t);
int vm_map_find(vm_map_t, vm_object_t, vm_ooffset_t, vm_offset_t *, vm_size_t,
    vm_offset_t, int, vm_prot_t, vm_prot_t, int);
int vm_map_find_locked(vm_map_t, vm_object_t, vm_ooffset_t, vm_offset_t *,
    vm_size_t, vm_offset_t, int, vm_prot_t, vm_prot_t, int);
int vm_map_find_min(vm_map_t, vm_object_t, vm_ooffset_t, vm_offset_t *,
    vm_size_t, vm_offset_t, vm_offset_t, int, vm_prot_t, vm_prot_t, int);
int vm_map_find_aligned(vm_map_t map, vm_offset_t *addr, vm_size_t length,
    vm_offset_t max_addr, vm_offset_t alignment);
int vm_map_fixed(vm_map_t, vm_object_t, vm_ooffset_t, vm_offset_t, vm_size_t,
    vm_prot_t, vm_prot_t, int);
vm_offset_t vm_map_findspace(vm_map_t, vm_offset_t, vm_size_t);
int vm_map_inherit (vm_map_t, vm_offset_t, vm_offset_t, vm_inherit_t);
void vm_map_init(vm_map_t, pmap_t, vm_offset_t, vm_offset_t);
int vm_map_insert (vm_map_t, vm_object_t, vm_ooffset_t, vm_offset_t, vm_offset_t, vm_prot_t, vm_prot_t, int);
int vm_map_lookup (vm_map_t *, vm_offset_t, vm_prot_t, vm_map_entry_t *, vm_object_t *,
    vm_pindex_t *, vm_prot_t *, boolean_t *);
int vm_map_lookup_locked(vm_map_t *, vm_offset_t, vm_prot_t, vm_map_entry_t *, vm_object_t *,
    vm_pindex_t *, vm_prot_t *, boolean_t *);
void vm_map_lookup_done (vm_map_t, vm_map_entry_t);
boolean_t vm_map_lookup_entry (vm_map_t, vm_offset_t, vm_map_entry_t *);

static inline vm_map_entry_t
vm_map_entry_first(vm_map_t map)
{

	return (map->header.right);
}

static inline vm_map_entry_t
vm_map_entry_succ(vm_map_entry_t entry)
{
	vm_map_entry_t after;

	after = entry->right;
	if (after->left->start > entry->start) {
		do
			after = after->left;
		while (after->left != entry);
	}
	return (after);
}

#define VM_MAP_ENTRY_FOREACH(it, map)		\
	for ((it) = vm_map_entry_first(map);	\
	    (it) != &(map)->header;		\
	    (it) = vm_map_entry_succ(it))

#define	VM_MAP_PROTECT_SET_PROT		0x0001
#define	VM_MAP_PROTECT_SET_MAXPROT	0x0002
#define	VM_MAP_PROTECT_GROWSDOWN	0x0004

int vm_map_protect(vm_map_t map, vm_offset_t start, vm_offset_t end,
    vm_prot_t new_prot, vm_prot_t new_maxprot, int flags);
int vm_map_remove (vm_map_t, vm_offset_t, vm_offset_t);
vm_map_entry_t vm_map_try_merge_entries(vm_map_t map, vm_map_entry_t prev,
    vm_map_entry_t entry);
void vm_map_startup (void);
int vm_map_submap (vm_map_t, vm_offset_t, vm_offset_t, vm_map_t);
int vm_map_sync(vm_map_t, vm_offset_t, vm_offset_t, boolean_t, boolean_t);
int vm_map_madvise (vm_map_t, vm_offset_t, vm_offset_t, int);
int vm_map_stack (vm_map_t, vm_offset_t, vm_size_t, vm_prot_t, vm_prot_t, int);
int vm_map_unwire(vm_map_t map, vm_offset_t start, vm_offset_t end,
    int flags);
int vm_map_wire(vm_map_t map, vm_offset_t start, vm_offset_t end, int flags);
int vm_map_wire_locked(vm_map_t map, vm_offset_t start, vm_offset_t end,
    int flags);
long vmspace_swap_count(struct vmspace *vmspace);
void vm_map_entry_set_vnode_text(vm_map_entry_t entry, bool add);
#endif				/* _KERNEL */
#endif				/* _VM_MAP_ */