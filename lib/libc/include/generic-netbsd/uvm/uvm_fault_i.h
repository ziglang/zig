/*	$NetBSD: uvm_fault_i.h,v 1.33 2020/02/23 15:46:43 ad Exp $	*/

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
 *
 * from: Id: uvm_fault_i.h,v 1.1.6.1 1997/12/08 16:07:12 chuck Exp
 */

#ifndef _UVM_UVM_FAULT_I_H_
#define _UVM_UVM_FAULT_I_H_

/*
 * uvm_fault_i.h: fault inline functions
 */
void uvmfault_update_stats(struct uvm_faultinfo *);


/*
 * uvmfault_unlockmaps: unlock the maps
 */

static __inline void
uvmfault_unlockmaps(struct uvm_faultinfo *ufi, bool write_locked)
{
	/*
	 * ufi can be NULL when this isn't really a fault,
	 * but merely paging in anon data.
	 */

	if (ufi == NULL) {
		return;
	}

#ifndef __HAVE_NO_PMAP_STATS
	uvmfault_update_stats(ufi);
#endif
	if (write_locked) {
		vm_map_unlock(ufi->map);
	} else {
		vm_map_unlock_read(ufi->map);
	}
}

/*
 * uvmfault_unlockall: unlock everything passed in.
 *
 * => maps must be read-locked (not write-locked).
 */

static __inline void
uvmfault_unlockall(struct uvm_faultinfo *ufi, struct vm_amap *amap,
    struct uvm_object *uobj)
{

	if (uobj)
		rw_exit(uobj->vmobjlock);
	if (amap)
		amap_unlock(amap);
	uvmfault_unlockmaps(ufi, false);
}

/*
 * uvmfault_lookup: lookup a virtual address in a map
 *
 * => caller must provide a uvm_faultinfo structure with the IN
 *	params properly filled in
 * => we will lookup the map entry (handling submaps) as we go
 * => if the lookup is a success we will return with the maps locked
 * => if "write_lock" is true, we write_lock the map, otherwise we only
 *	get a read lock.
 * => note that submaps can only appear in the kernel and they are
 *	required to use the same virtual addresses as the map they
 *	are referenced by (thus address translation between the main
 *	map and the submap is unnecessary).
 */

static __inline bool
uvmfault_lookup(struct uvm_faultinfo *ufi, bool write_lock)
{
	struct vm_map *tmpmap;

	/*
	 * init ufi values for lookup.
	 */

	ufi->map = ufi->orig_map;
	ufi->size = ufi->orig_size;

	/*
	 * keep going down levels until we are done.   note that there can
	 * only be two levels so we won't loop very long.
	 */

	for (;;) {
		/*
		 * lock map
		 */
		if (write_lock) {
			vm_map_lock(ufi->map);
		} else {
			vm_map_lock_read(ufi->map);
		}

		/*
		 * lookup
		 */
		if (!uvm_map_lookup_entry(ufi->map, ufi->orig_rvaddr,
		    &ufi->entry)) {
			uvmfault_unlockmaps(ufi, write_lock);
			return(false);
		}

		/*
		 * reduce size if necessary
		 */
		if (ufi->entry->end - ufi->orig_rvaddr < ufi->size)
			ufi->size = ufi->entry->end - ufi->orig_rvaddr;

		/*
		 * submap?    replace map with the submap and lookup again.
		 * note: VAs in submaps must match VAs in main map.
		 */
		if (UVM_ET_ISSUBMAP(ufi->entry)) {
			tmpmap = ufi->entry->object.sub_map;
			if (write_lock) {
				vm_map_unlock(ufi->map);
			} else {
				vm_map_unlock_read(ufi->map);
			}
			ufi->map = tmpmap;
			continue;
		}

		/*
		 * got it!
		 */

		ufi->mapv = ufi->map->timestamp;
		return(true);

	}	/* while loop */

	/*NOTREACHED*/
}

/*
 * uvmfault_relock: attempt to relock the same version of the map
 *
 * => fault data structures should be unlocked before calling.
 * => if a success (true) maps will be locked after call.
 */

static __inline bool
uvmfault_relock(struct uvm_faultinfo *ufi)
{
	/*
	 * ufi can be NULL when this isn't really a fault,
	 * but merely paging in anon data.
	 */

	if (ufi == NULL) {
		return true;
	}

	cpu_count(CPU_COUNT_FLTRELCK, 1);

	/*
	 * relock map.   fail if version mismatch (in which case nothing
	 * gets locked).
	 */

	vm_map_lock_read(ufi->map);
	if (ufi->mapv != ufi->map->timestamp) {
		vm_map_unlock_read(ufi->map);
		return(false);
	}

	cpu_count(CPU_COUNT_FLTRELCKOK, 1);
	return(true);
}

#endif /* _UVM_UVM_FAULT_I_H_ */