/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
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
 *	@(#)vm_extern.h	8.2 (Berkeley) 1/12/94
 */

#ifndef _VM_EXTERN_H_
#define	_VM_EXTERN_H_

struct pmap;
struct proc;
struct vmspace;
struct vnode;
struct vmem;

#ifdef _KERNEL
#include <sys/kassert.h>

struct cdev;
struct cdevsw;
struct domainset;

/* These operate on kernel virtual addresses only. */
vm_offset_t kva_alloc(vm_size_t);
vm_offset_t kva_alloc_aligned(vm_size_t, vm_size_t);
void kva_free(vm_offset_t, vm_size_t);

/* These operate on pageable virtual addresses. */
vm_offset_t kmap_alloc_wait(vm_map_t, vm_size_t);
void kmap_free_wakeup(vm_map_t, vm_offset_t, vm_size_t);

/* These operate on virtual addresses backed by memory. */
void *kmem_alloc_attr(vm_size_t size, int flags,
    vm_paddr_t low, vm_paddr_t high, vm_memattr_t memattr);
void *kmem_alloc_attr_domainset(struct domainset *ds, vm_size_t size,
    int flags, vm_paddr_t low, vm_paddr_t high, vm_memattr_t memattr);
void *kmem_alloc_contig(vm_size_t size, int flags,
    vm_paddr_t low, vm_paddr_t high, u_long alignment, vm_paddr_t boundary,
    vm_memattr_t memattr);
void *kmem_alloc_contig_domainset(struct domainset *ds, vm_size_t size,
    int flags, vm_paddr_t low, vm_paddr_t high, u_long alignment,
    vm_paddr_t boundary, vm_memattr_t memattr);
void *kmem_malloc(vm_size_t size, int flags);
void *kmem_malloc_domainset(struct domainset *ds, vm_size_t size,
    int flags);
void kmem_free(void *addr, vm_size_t size);

/* This provides memory for previously allocated address space. */
int kmem_back(vm_object_t, vm_offset_t, vm_size_t, int);
int kmem_back_domain(int, vm_object_t, vm_offset_t, vm_size_t, int);
void kmem_unback(vm_object_t, vm_offset_t, vm_size_t);

/* Bootstrapping. */
void kmem_bootstrap_free(vm_offset_t, vm_size_t);
void kmem_subinit(vm_map_t, vm_map_t, vm_offset_t *, vm_offset_t *, vm_size_t,
    bool);
void kmem_init(vm_offset_t, vm_offset_t);
void kmem_init_zero_region(void);
void kmeminit(void);

int kernacc(void *, int, int);
int useracc(void *, int, int);
int vm_fault(vm_map_t map, vm_offset_t vaddr, vm_prot_t fault_type,
    int fault_flags, vm_page_t *m_hold);
void vm_fault_copy_entry(vm_map_t, vm_map_t, vm_map_entry_t, vm_map_entry_t,
    vm_ooffset_t *);
int vm_fault_disable_pagefaults(void);
void vm_fault_enable_pagefaults(int save);
int vm_fault_quick_hold_pages(vm_map_t map, vm_offset_t addr, vm_size_t len,
    vm_prot_t prot, vm_page_t *ma, int max_count);
int vm_fault_trap(vm_map_t map, vm_offset_t vaddr, vm_prot_t fault_type,
    int fault_flags, int *signo, int *ucode);
int vm_forkproc(struct thread *, struct proc *, struct thread *,
    struct vmspace *, int);
void vm_waitproc(struct proc *);
int vm_mmap(vm_map_t, vm_offset_t *, vm_size_t, vm_prot_t, vm_prot_t, int,
    objtype_t, void *, vm_ooffset_t);
int vm_mmap_object(vm_map_t, vm_offset_t *, vm_size_t, vm_prot_t,
    vm_prot_t, int, vm_object_t, vm_ooffset_t, boolean_t, struct thread *);
int vm_mmap_to_errno(int rv);
int vm_mmap_cdev(struct thread *, vm_size_t, vm_prot_t, vm_prot_t *,
    int *, struct cdev *, struct cdevsw *, vm_ooffset_t *, vm_object_t *);
int vm_mmap_vnode(struct thread *, vm_size_t, vm_prot_t, vm_prot_t *, int *,
    struct vnode *, vm_ooffset_t *, vm_object_t *, boolean_t *);
void vm_set_page_size(void);
void vm_sync_icache(vm_map_t, vm_offset_t, vm_size_t);
typedef int (*pmap_pinit_t)(struct pmap *pmap);
struct vmspace *vmspace_alloc(vm_offset_t, vm_offset_t, pmap_pinit_t);
struct vmspace *vmspace_fork(struct vmspace *, vm_ooffset_t *);
int vmspace_exec(struct proc *, vm_offset_t, vm_offset_t);
int vmspace_unshare(struct proc *);
void vmspace_exit(struct thread *);
struct vmspace *vmspace_acquire_ref(struct proc *);
void vmspace_free(struct vmspace *);
void vmspace_exitfree(struct proc *);
void vmspace_switch_aio(struct vmspace *);
void vnode_pager_setsize(struct vnode *, vm_ooffset_t);
void vnode_pager_purge_range(struct vnode *, vm_ooffset_t, vm_ooffset_t);
int vslock(void *, size_t);
void vsunlock(void *, size_t);
struct sf_buf *vm_imgact_map_page(vm_object_t object, vm_ooffset_t offset);
void vm_imgact_unmap_page(struct sf_buf *sf);
void vm_thread_dispose(struct thread *td);
int vm_thread_new(struct thread *td, int pages);
void vm_thread_stack_back(struct domainset *ds, vm_offset_t kaddr,
    vm_page_t ma[], int npages, int req_class);
u_int vm_active_count(void);
u_int vm_inactive_count(void);
u_int vm_laundry_count(void);
u_int vm_wait_count(void);

/*
 * Is pa a multiple of alignment, which is a power-of-two?
 */
static inline bool
vm_addr_align_ok(vm_paddr_t pa, u_long alignment)
{
	KASSERT(powerof2(alignment), ("%s: alignment is not a power of 2: %#lx",
	    __func__, alignment));
	return ((pa & (alignment - 1)) == 0);
}

/*
 * Do the first and last addresses of a range match in all bits except the ones
 * in -boundary (a power-of-two)?  For boundary == 0, all addresses match.
 */
static inline bool
vm_addr_bound_ok(vm_paddr_t pa, vm_paddr_t size, vm_paddr_t boundary)
{
	KASSERT(powerof2(boundary), ("%s: boundary is not a power of 2: %#jx",
	    __func__, (uintmax_t)boundary));
	return (((pa ^ (pa + size - 1)) & -boundary) == 0);
}

static inline bool
vm_addr_ok(vm_paddr_t pa, vm_paddr_t size, u_long alignment,
    vm_paddr_t boundary)
{
	return (vm_addr_align_ok(pa, alignment) &&
	    vm_addr_bound_ok(pa, size, boundary));
}
#endif				/* _KERNEL */
#endif				/* !_VM_EXTERN_H_ */