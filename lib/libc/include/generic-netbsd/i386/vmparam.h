/*	$NetBSD: vmparam.h,v 1.88 2022/08/21 13:15:15 riastradh Exp $	*/

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
 *	@(#)vmparam.h	5.9 (Berkeley) 5/12/91
 */

#ifndef _I386_VMPARAM_H_
#define _I386_VMPARAM_H_

#include <sys/mutex.h>

#include <machine/pte.h>

/*
 * Machine dependent constants for 386.
 */

/*
 * Page size on the IA-32 is not variable in the traditional sense.
 * We override the PAGE_* definitions to compile-time constants.
 */
#define	PAGE_SHIFT	12
#define	PAGE_SIZE	(1 << PAGE_SHIFT)
#define	PAGE_MASK	(PAGE_SIZE - 1)

/*
 * Virtual address space arrangement. On 386, both user and kernel
 * share the address space, not unlike the vax.
 * USRSTACK is the top (end) of the user stack. Immediately above the
 * user stack is the page table map, and then kernel address space.
 */
#define	USRSTACK	VM_MAXUSER_ADDRESS

/*
 * Virtual memory related constants, all in bytes
 */
#define	MAXTSIZ		(256*1024*1024)		/* max text size */
#ifndef DFLDSIZ
#define	DFLDSIZ		(256*1024*1024)		/* initial data size limit */
#endif
#ifndef MAXDSIZ
#define	MAXDSIZ		(3U*1024*1024*1024)	/* 3G max data size */
#endif
#ifndef MAXDSIZ_BU
#define	MAXDSIZ_BU	(2U*1024*1024*1024 +	/* 2.5G max data size for */ \
			 1U* 512*1024*1024)	/* bottom-up allocation */ \
						/* could be a bit more */
#endif
#ifndef	DFLSSIZ
#define	DFLSSIZ		(2*1024*1024)		/* initial stack size limit */
#endif
#ifndef	MAXSSIZ
#define	MAXSSIZ		(64*1024*1024)		/* max stack size */
#endif

/*
 * IA-32 can't do per-page execute permission, so instead we implement
 * two executable segments for %cs, one that covers everything and one
 * that excludes some of the address space (currently just the stack).
 * I386_MAX_EXE_ADDR is the upper boundary for the smaller segment.
 */
#define I386_MAX_EXE_ADDR	(USRSTACK - MAXSSIZ)

/*
 * Size of User Raw I/O map
 */
#define	USRIOSIZE 	300

/*
 * See pmap_private.h for details.
 */
#ifdef PAE
#define L2_SLOT_PTE	(KERNBASE/NBPD_L2-4) /* 1532: for recursive PDP map */
#define L2_SLOT_KERN	(KERNBASE/NBPD_L2)   /* 1536: start of kernel space */
#else /* PAE */
#define L2_SLOT_PTE	(KERNBASE/NBPD_L2-1) /* 767: for recursive PDP map */
#define L2_SLOT_KERN	(KERNBASE/NBPD_L2)   /* 768: start of kernel space */
#endif /* PAE */

#define L2_SLOT_KERNBASE L2_SLOT_KERN

#define PDIR_SLOT_KERN	L2_SLOT_KERN
#define PDIR_SLOT_PTE	L2_SLOT_PTE

/* size of a PDP: usually one page, except for PAE */
#ifdef PAE
#define PDP_SIZE 4
#else
#define PDP_SIZE 1
#endif

/* largest value (-1 for APTP space) */
#define NKL2_MAX_ENTRIES	(NTOPLEVEL_PDES - (KERNBASE/NBPD_L2) - 1)
#define NKL1_MAX_ENTRIES	(unsigned long)(NKL2_MAX_ENTRIES * NPDPG)

#define NKL2_KIMG_ENTRIES	0	/* XXX unused */

#define NKL2_START_ENTRIES	0	/* XXX computed on runtime */
#define NKL1_START_ENTRIES	0	/* XXX unused */

#ifndef XENPV
#define NTOPLEVEL_PDES		(PAGE_SIZE * PDP_SIZE / (sizeof (pd_entry_t)))
#else	/* !XENPV */
#ifdef  PAE
#define NTOPLEVEL_PDES		1964	/* 1964-2047 reserved by Xen */
#else	/* PAE */
#define NTOPLEVEL_PDES		1008	/* 1008-1023 reserved by Xen */
#endif	/* PAE */
#endif  /* !XENPV */

/*
 * Mach derived constants
 */

/* user/kernel map constants */
#define VM_MIN_ADDRESS		((vaddr_t)0)
#define	VM_MAXUSER_ADDRESS	((vaddr_t)(PDIR_SLOT_PTE << L2_SHIFT) - PAGE_SIZE)
#define	VM_MAX_ADDRESS		\
	((vaddr_t)((PDIR_SLOT_PTE << L2_SHIFT) + (PDIR_SLOT_PTE << L1_SHIFT)))
#define	VM_MIN_KERNEL_ADDRESS	((vaddr_t)(PDIR_SLOT_KERN << L2_SHIFT))
#define	VM_MAX_KERNEL_ADDRESS	((vaddr_t)((PDIR_SLOT_KERN + NKL2_MAX_ENTRIES) << L2_SHIFT))

/*
 * The address to which unspecified mapping requests default
 */
#ifdef _KERNEL_OPT
#include "opt_uvm.h"
#include "opt_xen.h"
#endif
#define __USE_TOPDOWN_VM
#define VM_DEFAULT_ADDRESS_BOTTOMUP(da, sz) \
    round_page((vaddr_t)(da) + (vsize_t)MIN(maxdmap, MAXDSIZ_BU))

/* virtual sizes (bytes) for various kernel submaps */
#define VM_PHYS_SIZE		(USRIOSIZE*PAGE_SIZE)

#define VM_PHYSSEG_STRAT	VM_PSTRAT_BIGFIRST

#ifdef XENPV
#define	VM_PHYSSEG_MAX		1
#define	VM_NFREELIST		1
#else
#define	VM_PHYSSEG_MAX		32	/* 1 "hole" + 31 free lists */
#define	VM_NFREELIST		4
#define	VM_FREELIST_FIRST16	3
#define	VM_FREELIST_FIRST1G	2
#define	VM_FREELIST_FIRST4G	1
#endif /* XENPV */
#define	VM_FREELIST_DEFAULT	0

#endif /* _I386_VMPARAM_H_ */