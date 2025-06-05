/*	$NetBSD: vmparam.h,v 1.55 2022/08/20 23:48:50 riastradh Exp $	*/

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

#ifndef _X86_64_VMPARAM_H_
#define _X86_64_VMPARAM_H_

#ifdef __x86_64__

#include <sys/mutex.h>
#ifdef _KERNEL_OPT
#include "opt_xen.h"
#endif

/*
 * Machine dependent constants for 386.
 */

/*
 * Page size on the amd64 s not variable in the traditional sense.
 * We override the PAGE_* definitions to compile-time constants.
 */
#define	PAGE_SHIFT	12
#define	PAGE_SIZE	(1 << PAGE_SHIFT)
#define	PAGE_MASK	(PAGE_SIZE - 1)

/*
 * Default pager_map of 16MB is awfully small.  There is plenty
 * of VA so use it.
 */
#define	PAGER_MAP_DEFAULT_SIZE (512 * 1024 * 1024)

/*
 * Defaults for Unified Buffer Cache parameters.
 */

#ifndef UBC_WINSHIFT
#define	UBC_WINSHIFT	16	/* 64kB */
#endif
#ifndef UBC_NWINS
#define	UBC_NWINS	4096	/* 256MB */
#endif

/*
 * USRSTACK is the top (end) of the user stack. Immediately above the
 * user stack resides the user structure, which is UPAGES long and contains
 * the kernel stack.
 *
 * Immediately after the user structure is the page table map, and then
 * kernel address space.
 */
#define	USRSTACK	VM_MAXUSER_ADDRESS

#define USRSTACK32	VM_MAXUSER_ADDRESS32

/*
 * Virtual memory related constants, all in bytes
 */
#define	MAXTSIZ		(8L*1024*1024*1024)	/* max text size */
#ifndef DFLDSIZ
#define	DFLDSIZ		(256*1024*1024)		/* initial data size limit */
#endif
#ifndef MAXDSIZ
#define	MAXDSIZ		(8L*1024*1024*1024)	/* max data size */
#endif
#ifndef	DFLSSIZ
#define	DFLSSIZ		(4*1024*1024)		/* initial stack size limit */
#endif
#ifndef	MAXSSIZ
#define	MAXSSIZ		(128*1024*1024)		/* max stack size */
#endif

/*
 * 32bit memory related constants.
 */

#ifndef DFLDSIZ32
#define	DFLDSIZ32	(256*1024*1024)		/* initial data size limit */
#endif
#ifndef MAXDSIZ32
#define	MAXDSIZ32	(3U*1024*1024*1024)	/* max data size */
#endif
#ifndef	DFLSSIZ32
#define	DFLSSIZ32	(2*1024*1024)		/* initial stack size limit */
#endif
#ifndef	MAXSSIZ32
#define	MAXSSIZ32	(64*1024*1024)		/* max stack size */
#endif

/*
 * Size of User Raw I/O map
 */
#define	USRIOSIZE 	300

/* User map constants */
#define VM_MIN_ADDRESS		0
#define VM_MAXUSER_ADDRESS	(0x00007f8000000000 - PAGE_SIZE)
#define VM_MAXUSER_ADDRESS32	0xfffff000
#define VM_MAX_ADDRESS		0x00007fbfdfeff000

/*
 * Kernel map constants.
 * MIN = VA_SIGN_NEG(L4_SLOT_KERN * NBPD_L4)
 * MAX = MIN + NKL4_MAX_ENTRIES * NBPD_L4
 */
#ifndef XENPV
#define VM_MIN_KERNEL_ADDRESS_DEFAULT	0xffff800000000000
#define VM_MAX_KERNEL_ADDRESS_DEFAULT	0xffffa00000000000
#else
#define VM_MIN_KERNEL_ADDRESS_DEFAULT	0xffffa00000000000
#define VM_MAX_KERNEL_ADDRESS_DEFAULT	0xffffc00000000000
#endif

#if defined(_KMEMUSER) || defined(_KERNEL)
extern vaddr_t vm_min_kernel_address;
extern vaddr_t vm_max_kernel_address;
#define VM_MIN_KERNEL_ADDRESS	vm_min_kernel_address
#define VM_MAX_KERNEL_ADDRESS	vm_max_kernel_address
#endif

#define	PDP_SIZE	1

/*
 * The address to which unspecified mapping requests default
 */
#ifdef _KERNEL_OPT
#include "opt_uvm.h"
#endif
#define __USE_TOPDOWN_VM

#define VM_DEFAULT_ADDRESS_BOTTOMUP(da, sz) \
    round_page((vaddr_t)(da) + (vsize_t)maxdmap)

#define VM_DEFAULT_ADDRESS32_TOPDOWN(da, sz) \
	trunc_page(USRSTACK32 - MAXSSIZ32 - (sz) - user_stack_guard_size)
#define VM_DEFAULT_ADDRESS32_BOTTOMUP(da, sz) \
    round_page((vaddr_t)(da) + (vsize_t)MAXDSIZ32)

/* virtual sizes (bytes) for various kernel submaps */
#define VM_PHYS_SIZE		(USRIOSIZE*PAGE_SIZE)

#define VM_PHYSSEG_MAX		64	/* 1 "hole" + 63 free lists */
#define VM_PHYSSEG_STRAT	VM_PSTRAT_BIGFIRST

#define	VM_NFREELIST		6
#define	VM_FREELIST_DEFAULT	0
#define	VM_FREELIST_FIRST1T	1
#define	VM_FREELIST_FIRST64G	2
#define	VM_FREELIST_FIRST4G	3
#define	VM_FREELIST_FIRST1G	4
#define	VM_FREELIST_FIRST16	5

#else	/*	!__x86_64__	*/

#include <i386/vmparam.h>

#endif	/*	__x86_64__	*/

#endif /* _X86_64_VMPARAM_H_ */