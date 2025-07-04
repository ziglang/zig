/*	$NetBSD: vmparam.h,v 1.66.10.1 2023/05/15 10:37:24 martin Exp $	*/

/*
 * Copyright (c) 1988 University of Utah.
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * the Systems Programming Group of the University of Utah Computer
 * Science Department and Ralph Campbell.
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
 * from: Utah Hdr: vmparam.h 1.16 91/01/18
 *
 *	@(#)vmparam.h	8.2 (Berkeley) 4/22/94
 */

#ifndef _MIPS_VMPARAM_H_
#define	_MIPS_VMPARAM_H_

#ifdef _KERNEL_OPT
#include "opt_cputype.h"
#include "opt_multiprocessor.h"
#include "opt_modular.h"
#endif

/*
 * Machine dependent VM constants for MIPS.
 */

/*
 * We normally use a 4K page but may use 16K on MIPS systems.
 * Override PAGE_* definitions to compile-time constants.
 */
#ifdef ENABLE_MIPS_16KB_PAGE
#define	PAGE_SHIFT	14
#elif defined(ENABLE_MIPS_8KB_PAGE) \
    || (!defined(ENABLE_MIPS_4KB_PAGE) && __mips >= 3)
#define	PAGE_SHIFT	13
#else /* defined(ENABLE_MIPS_4KB_PAGE) */
#define	PAGE_SHIFT	12
#endif
#define	PAGE_SIZE	(1 << PAGE_SHIFT)
#define	PAGE_MASK	(PAGE_SIZE - 1)

#define	MIN_PAGE_SHIFT	12
#define	MAX_PAGE_SHIFT	14

#define	MAX_PAGE_SIZE	(1 << MAX_PAGE_SHIFT)
#define	MIN_PAGE_SIZE	(1 << MIN_PAGE_SHIFT)

/*
 * USRSTACK is the top (end) of the user stack.
 *
 * USRSTACK needs to start a little below 0x8000000 because the R8000
 * and some QED CPUs perform some virtual address checks before the
 * offset is calculated.  We use 0x8000 since that's the max displacement
 * in an instruction.
 */
#define	USRSTACK	(VM_MAXUSER_ADDRESS-0x8000) /* Start of user stack */
#define	USRSTACK32	((uint32_t)VM_MAXUSER_ADDRESS32-0x8000)

/*
 * Virtual memory related constants, all in bytes
 */
#if defined(__mips_o32)
#ifndef MAXTSIZ
#define	MAXTSIZ		(128*1024*1024)		/* max text size */
#endif
#ifndef DFLDSIZ
#define	DFLDSIZ		(128*1024*1024)		/* initial data size limit */
#endif
#ifndef MAXDSIZ
#define	MAXDSIZ		(512*1024*1024)		/* max data size */
#endif
#ifndef	DFLSSIZ
#define	DFLSSIZ		(4*1024*1024)		/* initial stack size limit */
#endif
#ifndef	MAXSSIZ
#define	MAXSSIZ		(32*1024*1024)		/* max stack size */
#endif
#else
/*
 * 64-bit ABIs need more space.
 */
#ifndef MAXTSIZ
#define	MAXTSIZ		(128*1024*1024)		/* max text size */
#endif
#ifndef DFLDSIZ
#define	DFLDSIZ		(256*1024*1024)		/* initial data size limit */
#endif
#ifndef MAXDSIZ
#define	MAXDSIZ		(1536*1024*1024)	/* max data size */
#endif
#ifndef	DFLSSIZ
#define	DFLSSIZ		(4*1024*1024)		/* initial stack size limit */
#endif
#ifndef	MAXSSIZ
#define	MAXSSIZ		(120*1024*1024)		/* max stack size */
#endif
#endif /* !__mips_o32 */

/*
 * Virtual memory related constants, all in bytes
 */
#ifndef DFLDSIZ32
#define	DFLDSIZ32	DFLDSIZ			/* initial data size limit */
#endif
#ifndef MAXDSIZ32
#define	MAXDSIZ32	MAXDSIZ			/* max data size */
#endif
#ifndef	DFLSSIZ32
#define	DFLSSIZ32	DFLTSIZ			/* initial stack size limit */
#endif
#ifndef	MAXSSIZ32
#define	MAXSSIZ32	MAXSSIZ			/* max stack size */
#endif

/*
 * PTEs for mapping user space into the kernel for phyio operations.
 * The default PTE number is enough to cover 8 disks * MAXBSIZE.
 */
#ifndef USRIOSIZE
#define	USRIOSIZE	(MAXBSIZE/PAGE_SIZE * 8)
#endif

/*
 * Mach derived constants
 */

/*
 * user/kernel map constants
 * These are negative addresses since MIPS addresses are signed.
 */
#define	VM_MIN_ADDRESS		((vaddr_t)0x00000000)
#ifdef _LP64
#define	MIPS_VM_MAXUSER_ADDRESS	((vaddr_t) 1L << 40)
#ifdef ENABLE_MIPS_16KB_PAGE
#define	VM_MAXUSER_ADDRESS	mips_vm_maxuser_address
#else
#define	VM_MAXUSER_ADDRESS	MIPS_VM_MAXUSER_ADDRESS
#endif
#define	VM_MAX_ADDRESS		VM_MAXUSER_ADDRESS	/* 0x0000010000000000 */
#define	VM_MIN_KERNEL_ADDRESS	((vaddr_t) 3L << 62)	/* 0xC000000000000000 */
#define	VM_MAX_KERNEL_ADDRESS	((vaddr_t) -1L << 31)	/* 0xFFFFFFFF80000000 */
#else
#define	VM_MAXUSER_ADDRESS	((vaddr_t)-0x7fffffff-1)/* 0xFFFFFFFF80000000 */
#define	VM_MAX_ADDRESS		((vaddr_t)-0x7fffffff-1)/* 0xFFFFFFFF80000000 */
#define	VM_MIN_KERNEL_ADDRESS	((vaddr_t)-0x40000000)	/* 0xFFFFFFFFC0000000 */
#ifdef ENABLE_MIPS_TX3900
#define	VM_MAX_KERNEL_ADDRESS	((vaddr_t)-0x01000000)	/* 0xFFFFFFFFFF000000 */
#else
#define	VM_MAX_KERNEL_ADDRESS	((vaddr_t)-0x00004000)	/* 0xFFFFFFFFFFFFC000 */
#endif
#endif
#define	VM_MAXUSER_ADDRESS32	((vaddr_t)(1UL << 31))	/* 0x0000000080000000 */

/*
 * The address to which unspecified mapping requests default
 */
#define	__USE_TOPDOWN_VM

#define	VM_DEFAULT_ADDRESS_TOPDOWN(da, sz) \
    trunc_page(USRSTACK - MAXSSIZ - (sz) - user_stack_guard_size)
#define	VM_DEFAULT_ADDRESS_BOTTOMUP(da, sz) \
    round_page((vaddr_t)(da) + (vsize_t)maxdmap)

#define	VM_DEFAULT_ADDRESS32_TOPDOWN(da, sz) \
    trunc_page(USRSTACK32 - MAXSSIZ32 - (sz) - user_stack_guard_size)
#define	VM_DEFAULT_ADDRESS32_BOTTOMUP(da, sz) \
    round_page((vaddr_t)(da) + (vsize_t)MAXDSIZ32)

/* virtual sizes (bytes) for various kernel submaps */
#define	VM_PHYS_SIZE		(USRIOSIZE*PAGE_SIZE)

/* VM_PHYSSEG_MAX defined by platform-dependent code. */
#define	VM_PHYSSEG_STRAT	VM_PSTRAT_BSEARCH

#ifndef VM_NFREELIST
#define	VM_NFREELIST		16	/* 16 distinct memory segments */
#define	VM_FREELIST_DEFAULT	0
#define	VM_FREELIST_MAX		1
#endif

#ifdef _KERNEL
#ifdef ENABLE_MIPS_16KB_PAGE
extern vaddr_t mips_vm_maxuser_address;
#endif
#endif

#endif /* ! _MIPS_VMPARAM_H_ */