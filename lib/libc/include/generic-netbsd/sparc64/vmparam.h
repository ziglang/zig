/*	$NetBSD: vmparam.h,v 1.42.18.1 2023/02/08 16:40:45 martin Exp $ */

/*
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This software was developed by the Computer Systems Engineering group
 * at Lawrence Berkeley Laboratory under DARPA contract BG 91-66 and
 * contributed to Berkeley.
 *
 * All advertising materials mentioning features or use of this software
 * must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Lawrence Berkeley Laboratory.
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
 *	@(#)vmparam.h	8.1 (Berkeley) 6/11/93
 */

/*
 * Machine dependent constants for Sun 4U and 4V UltraSPARC
 */

#ifndef VMPARAM_H
#define VMPARAM_H

#define __USE_TOPDOWN_VM

/*
 * We use 8K VM pages on the Sun4U.  Override the PAGE_* definitions
 * to be compile-time constants.
 */
#define	PAGE_SHIFT	13
#define	PAGE_SIZE	(1 << PAGE_SHIFT)
#define	PAGE_MASK	(PAGE_SIZE - 1)

/*
 * Default pager_map of 16MB is awfully small.  There is plenty
 * of VA so use it.
 */
#define        PAGER_MAP_DEFAULT_SIZE (512 * 1024 * 1024)

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
 * The kernel itself is mapped by the boot loader with 4Mb locked VM pages,
 * so let's keep 4Mb definitions here as well.
 */
#define PAGE_SHIFT_4M	22
#define PAGE_SIZE_4M	(1UL<<PAGE_SHIFT_4M)
#define PAGE_MASK_4M	(PAGE_SIZE_4M-1)

/*
 * USRSTACK is the top (end) of the user stack.
 */
#define USRSTACK32	0xffffe000L
#ifdef __arch64__
#define USRSTACK	0xffffffffffffe000L
#else
#define USRSTACK	USRSTACK32
#endif

/*
 * Virtual memory related constants, all in bytes
 */
#if __arch64__
/*
 * 64-bit limits:
 *
 * Since the compiler generates `call' instructions we can't
 * have more than 4GB in a single text segment.
 *
 * And since we only have a 40-bit adderss space, allow half
 * of that for data and the other half for stack.
 */
#ifndef MAXTSIZ
#define	MAXTSIZ		(4UL*1024*1024*1024)	/* max text size */
#endif
#ifndef DFLDSIZ
#define	DFLDSIZ		(128UL*1024*1024)	/* initial data size limit */
#endif
#ifndef MAXDSIZ
#define	MAXDSIZ		(1UL<<39)		/* 512GB max data size */
/*
 * For processes not using topdown VA, we need to limit the data size -
 * they probably have not been compiled with the proper compiler memory
 * model.
 */
#define VM_DEFAULT_ADDRESS_BOTTOMUP(da, sz) \
    round_page((vaddr_t)(da) + (vsize_t)uimax(maxdmap,1UL*1024*1024*1024))
#endif
#ifndef	DFLSSIZ
#define	DFLSSIZ		(2*1024*1024)		/* initial stack size limit */
#endif
#ifndef	MAXSSIZ
#define	MAXSSIZ		(128*1024*1024)		/* max stack size */
#endif
#else
/*
 * 32-bit limits:
 *
 * We only have 4GB to play with.  Limit data, and text
 * each to half of that and set a reasonable stack limit.
 *
 */
#ifndef MAXTSIZ
#define	MAXTSIZ		(2UL*1024*1024*1024)	/* max text size */
#endif
#ifndef DFLDSIZ
#define	DFLDSIZ		(128*1024*1024)		/* initial data size limit */
#endif
#ifndef MAXDSIZ
#define	MAXDSIZ		(2UL*1024*1024*1024)	/* max data size */
#endif
#ifndef	DFLSSIZ
#define	DFLSSIZ		(2*1024*1024)		/* initial stack size limit */
#endif
#ifndef	MAXSSIZ
#define	MAXSSIZ		(64*1024*1024)		/* max stack size */
#endif
#endif

/*
 * 32-bit emulation limits (same as sparc - we could go bigger)
 */
#ifndef DFLDSIZ32
#define	DFLDSIZ32	(64*1024*1024)		/* initial data size limit */
#endif
#ifndef MAXDSIZ32
#define	MAXDSIZ32	(512*1024*1024)		/* max data size */
#endif
#ifndef	DFLSSIZ32
#define	DFLSSIZ32	(2*1024*1024)		/* initial stack size limit */
#endif
#ifndef	MAXSSIZ32
#define	MAXSSIZ32	(32*1024*1024)		/* max stack size */
#endif

/*
 * Mach derived constants
 */

/*
 * User/kernel map constants.
 */
#define VM_MIN_ADDRESS		((vaddr_t)0)
#define VM_MAX_ADDRESS		(((vaddr_t)(-1))&~PGOFSET)
#define VM_MAXUSER_ADDRESS	VM_MAX_ADDRESS
#define VM_MAXUSER_ADDRESS32	((vaddr_t)(0x00000000ffffffffL&~PGOFSET))

#define VM_MIN_KERNEL_ADDRESS	((vaddr_t)KERNBASE)
#ifdef __arch64__
#define	VM_KERNEL_MEM_VA_START	((vaddr_t)0x100000000UL)
#define VM_MAX_KERNEL_ADDRESS	((vaddr_t)0x000007ffffffffffUL)
#else
#define VM_MAX_KERNEL_ADDRESS	((vaddr_t)KERNEND)
#endif

#define VM_PHYSSEG_MAX          32       /* up to 32 segments */
#define VM_PHYSSEG_STRAT        VM_PSTRAT_BSEARCH

#define	VM_NFREELIST		1
#define	VM_FREELIST_DEFAULT	0

#endif