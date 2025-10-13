/*-
 * SPDX-License-Identifier: BSD-4-Clause
 *
 * Copyright (c) 2001 David E. O'Brien
 * Copyright (c) 1990 The Regents of the University of California.
 * All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * William Jolitz.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
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
 *	from: @(#)param.h	5.8 (Berkeley) 6/28/91
 */

#ifndef _POWERPC_INCLUDE_PARAM_H_
#define	_POWERPC_INCLUDE_PARAM_H_

/*
 * Machine dependent constants for PowerPC
 */

#include <machine/_align.h>

/* Needed to display interrupts on OFW PCI */
#define __PCI_REROUTE_INTERRUPT

#ifndef MACHINE
#define	MACHINE		"powerpc"
#endif
#ifndef MACHINE_ARCH
#ifdef __powerpc64__
#if defined(__LITTLE_ENDIAN__)
#define	MACHINE_ARCH	"powerpc64le"
#else
#define	MACHINE_ARCH	"powerpc64"
#endif
#else
#ifdef	__SPE__
#define	MACHINE_ARCH	"powerpcspe"
#else
#define	MACHINE_ARCH	"powerpc"
#endif
#endif
#endif
#define	MID_MACHINE	MID_POWERPC
#ifdef __powerpc64__
#ifndef	MACHINE_ARCH32
#define	MACHINE_ARCH32	"powerpc"
#endif
#endif

#ifdef SMP
#ifndef MAXCPU
#define	MAXCPU		256
#endif
#else
#define	MAXCPU		1
#endif

#ifndef MAXMEMDOM
#define	MAXMEMDOM	8
#endif

#define	ALIGNBYTES	_ALIGNBYTES
#define	ALIGN(p)	_ALIGN(p)
/*
 * ALIGNED_POINTER is a boolean macro that checks whether an address
 * is valid to fetch data elements of type t from on this architecture.
 * This does not reflect the optimal alignment, just the possibility
 * (within reasonable limits). 
 */
#define	ALIGNED_POINTER(p, t)	((((uintptr_t)(p)) & (sizeof (t) - 1)) == 0)

/*
 * CACHE_LINE_SIZE is the compile-time maximum cache line size for an
 * architecture.  It should be used with appropriate caution.
 */
#define	CACHE_LINE_SHIFT	7
#define	CACHE_LINE_SIZE		(1 << CACHE_LINE_SHIFT)

#define	PAGE_SHIFT	12
#define	PAGE_SIZE	(1 << PAGE_SHIFT)	/* Page size */
#define	PAGE_MASK	(PAGE_SIZE - 1)
#define	NPTEPG		(PAGE_SIZE/(sizeof (pt_entry_t)))
#define	NPDEPG		(PAGE_SIZE/(sizeof (pt_entry_t)))

#define L1_PAGE_SIZE_SHIFT 39
#define L1_PAGE_SIZE (1UL<<L1_PAGE_SIZE_SHIFT)
#define L1_PAGE_MASK (L1_PAGE_SIZE-1)

#define L2_PAGE_SIZE_SHIFT 30
#define L2_PAGE_SIZE (1UL<<L2_PAGE_SIZE_SHIFT)
#define L2_PAGE_MASK (L2_PAGE_SIZE-1)

#define L3_PAGE_SIZE_SHIFT 21
#define L3_PAGE_SIZE (1UL<<L3_PAGE_SIZE_SHIFT)
#define L3_PAGE_MASK (L3_PAGE_SIZE-1)

#define	MAXPAGESIZES	3	/* maximum number of supported page sizes */

#define	RELOCATABLE_KERNEL	1		/* kernel may relocate during startup */

#ifndef KSTACK_PAGES
#ifdef __powerpc64__
#define	KSTACK_PAGES		12		/* includes pcb */
#else
#define	KSTACK_PAGES		4		/* includes pcb */
#endif
#endif
#define	KSTACK_GUARD_PAGES	1	/* pages of kstack guard; 0 disables */
#define	USPACE		(kstack_pages * PAGE_SIZE)	/* total size of pcb */

#define	COPYFAULT		0x1
#define	FUSUFAULT		0x2

/*
 * Mach derived conversion macros
 */
#define	trunc_page(x)		((x) & ~(PAGE_MASK))
#define	round_page(x)		(((x) + PAGE_MASK) & ~PAGE_MASK)
#define	trunc_2mpage(x)		((unsigned long)(x) & ~L3_PAGE_MASK)
#define	round_2mpage(x)		((((unsigned long)(x)) + L3_PAGE_MASK) & ~L3_PAGE_MASK)
#define	trunc_1gpage(x)		((unsigned long)(x) & ~L2_PAGE_MASK)

#define	atop(x)			((x) >> PAGE_SHIFT)
#define	ptoa(x)			((x) << PAGE_SHIFT)

#define	powerpc_btop(x)		((x) >> PAGE_SHIFT)
#define	powerpc_ptob(x)		((x) << PAGE_SHIFT)

#define	pgtok(x)		((x) * (PAGE_SIZE / 1024UL))

#define btoc(x)			((vm_offset_t)(((x)+PAGE_MASK)>>PAGE_SHIFT))

#endif /* !_POWERPC_INCLUDE_PARAM_H_ */