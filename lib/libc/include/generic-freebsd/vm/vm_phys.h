/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2002-2006 Rice University
 * Copyright (c) 2007 Alan L. Cox <alc@cs.rice.edu>
 * All rights reserved.
 *
 * This software was developed for the FreeBSD Project by Alan L. Cox,
 * Olivier Crameri, Peter Druschel, Sitaram Iyer, and Juan Navarro.
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
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT
 * HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
 * OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
 * AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 * WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/*
 *	Physical memory system definitions
 */

#ifndef	_VM_PHYS_H_
#define	_VM_PHYS_H_

#ifdef _KERNEL

#include <vm/_vm_phys.h>

extern vm_paddr_t phys_avail[];

/* Domains must be dense (non-sparse) and zero-based. */
struct mem_affinity {
	vm_paddr_t start;
	vm_paddr_t end;
	int domain;
};
#ifdef NUMA
extern struct mem_affinity *mem_affinity;
extern int *mem_locality;
#endif

/*
 * The following functions are only to be used by the virtual memory system.
 */
void vm_phys_add_seg(vm_paddr_t start, vm_paddr_t end);
vm_page_t vm_phys_alloc_contig(int domain, u_long npages, vm_paddr_t low,
    vm_paddr_t high, u_long alignment, vm_paddr_t boundary);
vm_page_t vm_phys_alloc_freelist_pages(int domain, int freelist, int pool,
    int order);
int vm_phys_alloc_npages(int domain, int pool, int npages, vm_page_t ma[]);
vm_page_t vm_phys_alloc_pages(int domain, int pool, int order);
int vm_phys_domain_match(int prefer, vm_paddr_t low, vm_paddr_t high);
void vm_phys_enqueue_contig(vm_page_t m, u_long npages);
int vm_phys_fictitious_reg_range(vm_paddr_t start, vm_paddr_t end,
    vm_memattr_t memattr);
void vm_phys_fictitious_unreg_range(vm_paddr_t start, vm_paddr_t end);
vm_page_t vm_phys_fictitious_to_vm_page(vm_paddr_t pa);
int vm_phys_find_range(vm_page_t bounds[], int segind, int domain,
    u_long npages, vm_paddr_t low, vm_paddr_t high);
void vm_phys_free_contig(vm_page_t m, u_long npages);
void vm_phys_free_pages(vm_page_t m, int order);
void vm_phys_init(void);
vm_page_t vm_phys_paddr_to_vm_page(vm_paddr_t pa);
void vm_phys_register_domains(int ndomains, struct mem_affinity *affinity,
    int *locality);
bool vm_phys_unfree_page(vm_page_t m);
int vm_phys_mem_affinity(int f, int t);
void vm_phys_early_add_seg(vm_paddr_t start, vm_paddr_t end);
vm_paddr_t vm_phys_early_alloc(int domain, size_t alloc_size);
void vm_phys_early_startup(void);
int vm_phys_avail_largest(void);
vm_paddr_t vm_phys_avail_size(int i);
bool vm_phys_is_dumpable(vm_paddr_t pa);

static inline int
vm_phys_domain(vm_paddr_t pa)
{
#ifdef NUMA
	int i;

	if (vm_ndomains == 1)
		return (0);
	for (i = 0; mem_affinity[i].end != 0; i++)
		if (mem_affinity[i].start <= pa &&
		    mem_affinity[i].end >= pa)
			return (mem_affinity[i].domain);
	return (-1);
#else
	return (0);
#endif
}

/*
 * Find the segind for the first segment at or after the given physical address.
 */
static inline int
vm_phys_lookup_segind(vm_paddr_t pa)
{
	u_int hi, lo, mid;

	lo = 0;
	hi = vm_phys_nsegs;
	while (lo != hi) {
		/*
		 * for i in [0, lo), segs[i].end <= pa
		 * for i in [hi, nsegs), segs[i].end > pa
		 */
		mid = lo + (hi - lo) / 2;
		if (vm_phys_segs[mid].end <= pa)
			lo = mid + 1;
		else
			hi = mid;
	}
	return (lo);
}

/*
 * Find the segment corresponding to the given physical address.
 */
static inline struct vm_phys_seg *
vm_phys_paddr_to_seg(vm_paddr_t pa)
{
	struct vm_phys_seg *seg;
	int segind;

	segind = vm_phys_lookup_segind(pa);
	if (segind < vm_phys_nsegs) {
		seg = &vm_phys_segs[segind];
		if (pa >= seg->start)
			return (seg);
	}
	return (NULL);
}

#endif	/* _KERNEL */
#endif	/* !_VM_PHYS_H_ */