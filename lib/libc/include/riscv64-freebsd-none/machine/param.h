/*-
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

#ifndef _MACHINE_PARAM_H_
#define	_MACHINE_PARAM_H_

/*
 * Machine dependent constants for RISC-V.
 */

#include <machine/_align.h>

#define	STACKALIGNBYTES	(16 - 1)
#define	STACKALIGN(p)	((uint64_t)(p) & ~STACKALIGNBYTES)

#define __PCI_REROUTE_INTERRUPT

#ifndef MACHINE
#define	MACHINE		"riscv"
#endif
#ifndef MACHINE_ARCH
#define	MACHINE_ARCH	"riscv64"
#endif

#ifdef SMP
#ifndef MAXCPU
#define	MAXCPU		16
#endif
#else
#define	MAXCPU		1
#endif

#ifndef MAXMEMDOM
#define	MAXMEMDOM	1
#endif

#define	ALIGNBYTES	_ALIGNBYTES
#define	ALIGN(p)	_ALIGN(p)
/*
 * ALIGNED_POINTER is a boolean macro that checks whether an address
 * is valid to fetch data elements of type t from on this architecture.
 * This does not reflect the optimal alignment, just the possibility
 * (within reasonable limits).
 */
#define	ALIGNED_POINTER(p, t)	((((u_long)(p)) & (sizeof(t) - 1)) == 0)

/*
 * CACHE_LINE_SIZE is the compile-time maximum cache line size for an
 * architecture.  It should be used with appropriate caution.
 */
#define	CACHE_LINE_SHIFT	6
#define	CACHE_LINE_SIZE		(1 << CACHE_LINE_SHIFT)

#define	PAGE_SHIFT	12
#define	PAGE_SIZE	(1 << PAGE_SHIFT)	/* Page size */
#define	PAGE_MASK	(PAGE_SIZE - 1)

#define	MAXPAGESIZES	3	/* maximum number of supported page sizes */

#ifndef KSTACK_PAGES
#define	KSTACK_PAGES	4	/* pages of kernel stack (with pcb) */
#endif

#define	KSTACK_GUARD_PAGES	1	/* pages of kstack guard; 0 disables */
#define	PCPU_PAGES		1

/*
 * Mach derived conversion macros
 */
#define	round_page(x)		(((unsigned long)(x) + PAGE_MASK) & ~PAGE_MASK)
#define	trunc_page(x)		((unsigned long)(x) & ~PAGE_MASK)

#define	atop(x)			((unsigned long)(x) >> PAGE_SHIFT)
#define	ptoa(x)			((unsigned long)(x) << PAGE_SHIFT)

#define	riscv_btop(x)		((unsigned long)(x) >> PAGE_SHIFT)
#define	riscv_ptob(x)		((unsigned long)(x) << PAGE_SHIFT)

#define	pgtok(x)		((unsigned long)(x) * (PAGE_SIZE / 1024))

#endif /* !_MACHINE_PARAM_H_ */