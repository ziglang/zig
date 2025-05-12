/*	$NetBSD: uvm_param.h,v 1.41.20.1 2023/08/09 17:42:01 martin Exp $	*/

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
 *	@(#)vm_param.h	8.2 (Berkeley) 1/9/95
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
 *	Machine independent virtual memory parameters.
 */

#ifndef	_VM_PARAM_
#define	_VM_PARAM_

#ifdef _KERNEL_OPT
#include "opt_modular.h"
#include "opt_uvm.h"
#endif
#ifdef _KERNEL
#include <sys/types.h>
#include <machine/vmparam.h>
#endif

#if defined(_KERNEL)

#if defined(PAGE_SIZE)

/*
 * If PAGE_SIZE is defined at this stage, it must be a constant.
 */

#if PAGE_SIZE == 0
#error Invalid PAGE_SIZE definition
#endif

/*
 * If the platform does not need to support a variable PAGE_SIZE,
 * then provide default values for MIN_PAGE_SIZE and MAX_PAGE_SIZE.
 */

#if !defined(MIN_PAGE_SIZE)
#define	MIN_PAGE_SIZE	PAGE_SIZE
#endif /* ! MIN_PAGE_SIZE */

#if !defined(MAX_PAGE_SIZE)
#define	MAX_PAGE_SIZE	PAGE_SIZE
#endif /* ! MAX_PAGE_SIZE */

#else /* ! PAGE_SIZE */

/*
 * PAGE_SIZE is not a constant; MIN_PAGE_SIZE and MAX_PAGE_SIZE must
 * be defined.
 */

#if !defined(MIN_PAGE_SIZE)
#error MIN_PAGE_SIZE not defined
#endif

#if !defined(MAX_PAGE_SIZE)
#error MAX_PAGE_SIZE not defined
#endif

#endif /* PAGE_SIZE */

/*
 * MIN_PAGE_SIZE and MAX_PAGE_SIZE must be constants.
 */

#if MIN_PAGE_SIZE == 0
#error Invalid MIN_PAGE_SIZE definition
#endif

#if MAX_PAGE_SIZE == 0
#error Invalid MAX_PAGE_SIZE definition
#endif

/*
 * If MIN_PAGE_SIZE and MAX_PAGE_SIZE are not equal, then we must use
 * non-constant PAGE_SIZE, et al for modules.
 */
#if (MIN_PAGE_SIZE != MAX_PAGE_SIZE)
#define	__uvmexp_pagesize
#if defined(_MODULE)
#undef PAGE_SIZE
#undef PAGE_MASK
#undef PAGE_SHIFT
#endif
#endif

/*
 * Now provide PAGE_SIZE, PAGE_MASK, and PAGE_SHIFT if we do not
 * have ones that are compile-time constants.
 */
#if !defined(PAGE_SIZE)
extern const int *const uvmexp_pagesize;
extern const int *const uvmexp_pagemask;
extern const int *const uvmexp_pageshift;
#define	PAGE_SIZE	(*uvmexp_pagesize)	/* size of page */
#define	PAGE_MASK	(*uvmexp_pagemask)	/* size of page - 1 */
#define	PAGE_SHIFT	(*uvmexp_pageshift)	/* bits to shift for pages */
#endif /* PAGE_SIZE */

#endif /* _KERNEL */

/*
 * CTL_VM identifiers
 */
#define	VM_METER	1		/* struct vmmeter */
#define	VM_LOADAVG	2		/* struct loadavg */
#define	VM_UVMEXP	3		/* struct uvmexp */
#define	VM_NKMEMPAGES	4		/* kmem_map pages */
#define	VM_UVMEXP2	5		/* struct uvmexp_sysctl */
#define	VM_ANONMIN	6
#define	VM_EXECMIN	7
#define	VM_FILEMIN	8
#define	VM_MAXSLP	9
#define	VM_USPACE	10
#define	VM_ANONMAX	11
#define	VM_EXECMAX	12
#define	VM_FILEMAX	13
#define	VM_MINADDRESS	14
#define	VM_MAXADDRESS	15
#define	VM_PROC		16		/* process information */
#define	VM_GUARD_SIZE	17		/* guard size for main thread */
#define	VM_THREAD_GUARD_SIZE	18	/* default guard size for new threads */

#define VM_PROC_MAP	1		/* struct kinfo_vmentry */

#ifndef ASSEMBLER
/*
 *	Convert addresses to pages and vice versa.
 *	No rounding is used.
 */
#ifdef _KERNEL
#define	atop(x)		(((paddr_t)(x)) >> PAGE_SHIFT)
#define	ptoa(x)		(((paddr_t)(x)) << PAGE_SHIFT)

/*
 * Round off or truncate to the nearest page.  These will work
 * for either addresses or counts (i.e., 1 byte rounds to 1 page).
 */
#define	round_page(x)	(((x) + PAGE_MASK) & ~PAGE_MASK)
#define	trunc_page(x)	((x) & ~PAGE_MASK)

#ifndef VM_DEFAULT_ADDRESS_BOTTOMUP
#define VM_DEFAULT_ADDRESS_BOTTOMUP(da, sz) \
    round_page((vaddr_t)(da) + (vsize_t)maxdmap)
#endif

extern unsigned int user_stack_guard_size;
extern unsigned int user_thread_stack_guard_size;
#ifndef VM_DEFAULT_ADDRESS_TOPDOWN
#define VM_DEFAULT_ADDRESS_TOPDOWN(da, sz) \
    trunc_page(VM_MAXUSER_ADDRESS - MAXSSIZ - (sz) - user_stack_guard_size)
#endif

extern int		ubc_nwins;	/* number of UBC mapping windows */
extern const int	ubc_winshift;	/* shift for a UBC mapping window */

#else
/* out-of-kernel versions of round_page and trunc_page */
#define	round_page(x) \
	((((vaddr_t)(x) + (vm_page_size - 1)) / vm_page_size) * \
	    vm_page_size)
#define	trunc_page(x) \
	((((vaddr_t)(x)) / vm_page_size) * vm_page_size)

#endif /* _KERNEL */

/*
 * typedefs, necessary for standard UVM headers.
 */

typedef unsigned int uvm_flag_t;

typedef int vm_inherit_t;	/* XXX: inheritance codes */
typedef off_t voff_t;		/* XXX: offset within a uvm_object */
typedef voff_t pgoff_t;		/* XXX: number of pages within a uvm object */

#endif /* ASSEMBLER */
#endif /* _VM_PARAM_ */