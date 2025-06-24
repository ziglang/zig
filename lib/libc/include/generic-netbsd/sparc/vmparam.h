/*	$NetBSD: vmparam.h,v 1.48 2019/03/29 20:18:09 christos Exp $ */

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

#ifndef _SPARC_VMPARAM_H_
#define _SPARC_VMPARAM_H_

#define __USE_TOPDOWN_VM

/*
 * Machine dependent constants for SPARC
 */

#include <machine/cpuconf.h>

/*
 * Sun4 systems have a 8K page size.  All other platforms have a
 * 4K page size.  We need to define these upper and lower limits
 * for machine-independent code.  We also try to make PAGE_SIZE,
 * PAGE_SHIFT, and PAGE_MASK into compile-time constants, if we can.
 *
 * XXX Should garbage-collect the version of this from <machine/param.h>.
 */
#define	PAGE_SHIFT_SUN4		13
#define	PAGE_SHIFT_SUN4CM	12

#define MAX_PAGE_SHIFT		PAGE_SHIFT_SUN4
#define MIN_PAGE_SHIFT		PAGE_SHIFT_SUN4CM

#define	MIN_PAGE_SIZE		(1 << MIN_PAGE_SHIFT)
#define	MAX_PAGE_SIZE		(1 << MAX_PAGE_SHIFT)

#if CPU_NTYPES != 0 && !defined(SUN4)
#define	PAGE_SHIFT		PAGE_SHIFT_SUN4CM
#elif CPU_NTYPES == 1 && defined(SUN4)
#define	PAGE_SHIFT		PAGE_SHIFT_SUN4
#endif

#ifdef	PAGE_SHIFT
#define	PAGE_SIZE		(1 << PAGE_SHIFT)
#define	PAGE_MASK		(PAGE_SIZE - 1)
#endif

/*
 * USRSTACK is the top (end) of the user stack.
 */
#define	USRSTACK	KERNBASE		/* Start of user stack */

/*
 * Virtual memory related constants, all in bytes
 */
#ifndef MAXTSIZ
#define	MAXTSIZ		(64*1024*1024)		/* max text size */
#endif
#ifndef DFLDSIZ
#define	DFLDSIZ		(64*1024*1024)		/* initial data size limit */
#endif
#ifndef MAXDSIZ
#define	MAXDSIZ		(512*1024*1024)		/* max data size */
#endif
#ifndef	DFLSSIZ
#define	DFLSSIZ		(8*1024*1024)		/* initial stack size limit */
#endif
#ifndef	MAXSSIZ
#define	MAXSSIZ		(32*1024*1024)		/* max stack size */
#endif

/*
 * Mach derived constants
 */

/*
 * User/kernel map constants.  Note that sparc/vaddrs.h defines the
 * IO space virtual base, which must be the same as VM_MAX_KERNEL_ADDRESS:
 * tread with care.
 */
#define VM_MIN_ADDRESS		((vaddr_t)0)
#define VM_MAX_ADDRESS		((vaddr_t)KERNBASE)
#define VM_MAXUSER_ADDRESS	((vaddr_t)KERNBASE)
#define VM_MIN_KERNEL_ADDRESS	((vaddr_t)KERNBASE)
#define VM_MAX_KERNEL_ADDRESS   ((vaddr_t)KERNEND)

#define VM_PHYSSEG_MAX		32       /* up to 32 segments */
#define VM_PHYSSEG_STRAT	VM_PSTRAT_BSEARCH

#define	VM_NFREELIST		1
#define	VM_FREELIST_DEFAULT	0

#endif /* _SPARC_VMPARAM_H_ */