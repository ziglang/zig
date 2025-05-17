/*	$NetBSD: uvm_pmap.h,v 1.43 2022/08/20 23:08:53 riastradh Exp $	*/

/*
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
 *	@(#)pmap.h	8.1 (Berkeley) 6/11/93
 *
 *
 * Copyright (c) 1987, 1990 Carnegie-Mellon University.
 * All rights reserved.
 *
 * Author: Avadis Tevanian, Jr.
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
 *	Machine address mapping definitions -- machine-independent
 *	section.  [For machine-dependent section, see "machine/pmap.h".]
 */

#ifndef	_PMAP_VM_
#define	_PMAP_VM_

#include <sys/types.h>

#include <uvm/uvm_prot.h>

struct lwp;		/* for pmap_activate()/pmap_deactivate() proto */
struct vm_page;

struct pmap;
typedef struct pmap *pmap_t;

/*
 * Each machine dependent implementation is expected to
 * keep certain statistics.  They may do this anyway they
 * so choose, but are expected to return the statistics
 * in the following structure.
 */
struct pmap_statistics {
	long		resident_count;	/* # of pages mapped (total)*/
	long		wired_count;	/* # of pages wired */
};
typedef struct pmap_statistics	*pmap_statistics_t;

#ifdef _KERNEL

extern struct pmap	*const kernel_pmap_ptr;
#define pmap_kernel()	kernel_pmap_ptr

#endif

/*
 * Cache Type Encodings
 */
#define PMAP_CACHE_MASK		0x00000f00

/* All accesses are uncacheable. No speculative accesses. */
#define PMAP_NOCACHE		0x00000100	/* [BOTH] */

/* All accesses are uncacheable. No speculative accesses.
 * Writes are combined. */
#define PMAP_WRITE_COMBINE	0x00000200	/* [BOTH] */

/* On reads, cachelines become shared or exclusive if allocated on cache miss.
 * On writes, cachelines become modified on a cache miss.  */
#define PMAP_WRITE_BACK		0x00000300	/* [BOTH] */

/* = PMAP_NOCACHE but overrideable (e.g. on x86 by MTRRs) */
#define PMAP_NOCACHE_OVR	0x00000400	/* [BOTH] */

#ifdef _KERNEL
#include <machine/pmap.h>
#endif

/*
 * Flags passed to pmap_enter().  Note the bottom 3 bits are VM_PROT_*
 * bits, used to indicate the access type that was made (to seed modified
 * and referenced information).
 *
 * Flags marked [PA] are for pmap_kenter_pa() only.  Flags marked [BOTH]
 * apply to pmap_kenter_pa() and pmap_enter().  All other flags are valid
 * for pmap_enter() only.
 */
#define	PMAP_WIRED	0x00000010	/* wired mapping */
#define	PMAP_CANFAIL	0x00000020	/* can fail if resource shortage */
#if defined(PMAP_ENABLE_PMAP_KMPAGE)
#define	PMAP_KMPAGE	0x00000040	/* [PA] page used for kernel memory */
#else
#define	PMAP_KMPAGE	0x00000000
#endif /* PMAP_ENABLE_PMAP_KMPAGE */

#define	PMAP_MD_MASK	0xff000000	/* [BOTH] Machine-dependent bits */
#define PMAP_PROT_MASK	0x0000000f	/* [BOTH] VM_PROT_* bit mask */

#ifndef PMAP_EXCLUDE_DECLS	/* Used in Sparc port to virtualize pmap mod */
#ifdef _KERNEL
void		pmap_activate(struct lwp *);
void		pmap_deactivate(struct lwp *);
void		pmap_unwire(pmap_t, vaddr_t);

#if !defined(pmap_clear_modify)
bool		pmap_clear_modify(struct vm_page *);
#endif
#if !defined(pmap_clear_reference)
bool		pmap_clear_reference(struct vm_page *);
#endif

#if !defined(pmap_copy)
void		pmap_copy(pmap_t, pmap_t, vaddr_t, vsize_t, vaddr_t);
#endif
#if !defined(pmap_copy_page)
void		pmap_copy_page(paddr_t, paddr_t);
#endif
struct pmap	*pmap_create(void);
void		pmap_destroy(pmap_t);
int		pmap_enter(pmap_t, vaddr_t, paddr_t, vm_prot_t, u_int);
bool		pmap_extract(pmap_t, vaddr_t, paddr_t *);
#if defined(PMAP_GROWKERNEL)
vaddr_t		pmap_growkernel(vaddr_t);
#endif

void		pmap_init(void);

#if !defined(pmap_kenter_pa)
void		pmap_kenter_pa(vaddr_t, paddr_t, vm_prot_t, u_int);
#endif
void		pmap_kremove(vaddr_t, vsize_t);
#if !defined(pmap_is_modified)
bool		pmap_is_modified(struct vm_page *);
#endif
#if !defined(pmap_is_referenced)
bool		pmap_is_referenced(struct vm_page *);
#endif

void		pmap_page_protect(struct vm_page *, vm_prot_t);
void		pmap_pv_protect(paddr_t, vm_prot_t);

#if !defined(pmap_phys_address)
paddr_t		pmap_phys_address(paddr_t);
#endif
#if !defined(pmap_mmap_flags)
#define		pmap_mmap_flags(x)	0
#endif
void		pmap_protect(pmap_t, vaddr_t, vaddr_t, vm_prot_t);
#if !defined(pmap_reference)
void		pmap_reference(pmap_t);
#endif
#if !defined(pmap_remove)
void		pmap_remove(pmap_t, vaddr_t, vaddr_t);
#endif
bool		pmap_remove_all(struct pmap *);
#if !defined(pmap_update)
void		pmap_update(pmap_t);
#endif
#if !defined(pmap_resident_count)
long		pmap_resident_count(pmap_t);
#endif
#if !defined(pmap_wired_count)
long		pmap_wired_count(pmap_t);
#endif
#if !defined(pmap_zero_page)
void		pmap_zero_page(paddr_t);
#endif

void		pmap_virtual_space(vaddr_t *, vaddr_t *);
#if defined(PMAP_STEAL_MEMORY)
vaddr_t		pmap_steal_memory(vsize_t, vaddr_t *, vaddr_t *);
#endif

#if defined(PMAP_FORK)
void		pmap_fork(pmap_t, pmap_t);
#endif

#if defined(PMAP_DIRECT)
int		pmap_direct_process(paddr_t, voff_t, size_t,
		    int (*)(void *, size_t, void *),
		    void *);
#endif

#endif	/* kernel*/
#endif  /* PMAP_EXCLUDE_DECLS */

#endif /* _PMAP_VM_ */