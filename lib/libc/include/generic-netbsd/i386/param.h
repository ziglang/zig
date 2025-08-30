/*	$NetBSD: param.h,v 1.88 2021/05/31 14:38:55 simonb Exp $	*/

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
 *	@(#)param.h	5.8 (Berkeley) 6/28/91
 */

#ifndef _I386_PARAM_H_
#define _I386_PARAM_H_

#ifdef _KERNEL_OPT
#include "opt_param.h"
#endif

/*
 * Machine dependent constants for Intel 386.
 */

/*
 * MAXCPUS must be defined before cpu.h inclusion.  Note: i386 might
 * support more CPUs, but due to the limited KVA space available on
 * i386, such support would be inefficient.  Use amd64 instead.
 */
#define	MAXCPUS		32

#ifdef _KERNEL
#include <machine/cpu.h>
#endif

#define	_MACHINE	i386
#define	MACHINE		"i386"
#define	_MACHINE_ARCH	i386
#define	MACHINE_ARCH	"i386"
#define	MID_MACHINE	MID_I386

#define ALIGNED_POINTER(p,t)		1
#define ALIGNED_POINTER_LOAD(q,p,t)	memcpy((q), (p), sizeof(t))

#define	PGSHIFT		12		/* LOG2(NBPG) */
#define	NBPG		(1 << PGSHIFT)	/* bytes/page */
#define	PGOFSET		(NBPG-1)	/* byte offset into page */
#define	NPTEPG		(NBPG/(sizeof (pt_entry_t)))

#define	MAXIOMEM	0xffffffff

/*
 * Maximum physical memory supported by the implementation.
 */
#ifdef PAE
#define MAXPHYSMEM	0x1000000000ULL /* 64GB */
#else
#define MAXPHYSMEM	0x100000000ULL	/* 4GB */
#endif

#if defined(_KERNEL_OPT)
#include "opt_kernbase.h"
#endif /* defined(_KERNEL_OPT) */

#ifndef	KERNBASE
#define	KERNBASE	0xc0000000UL	/* start of kernel virtual space */
#endif

#define	KERNTEXTOFF	(KERNBASE + 0x100000) /* start of kernel text */
#define	BTOPKERNBASE	(KERNBASE >> PGSHIFT)

#define	SSIZE		1		/* initial stack size/NBPG */
#define	SINCR		1		/* increment of stack/NBPG */

#ifndef UPAGES
# ifdef DIAGNOSTIC
#  define	UPAGES		3	/* 2 + 1 page for redzone */
# else
#  define	UPAGES		2	/* normal pages of u-area */
# endif /* DIAGNOSTIC */
#endif /* !defined(UPAGES) */
#define	USPACE		(UPAGES * NBPG)	/* total size of u-area */
#define	INTRSTACKSIZE	8192

#ifndef MSGBUFSIZE
#define MSGBUFSIZE	(16*NBPG)	/* default message buffer size */
#endif

/*
 * Constants related to network buffer management.
 * MCLBYTES must be no larger than NBPG (the software page size), and,
 * on machines that exchange pages of input or output buffers with mbuf
 * clusters (MAPPED_MBUFS), MCLBYTES must also be an integral multiple
 * of the hardware page size.
 */
#define	MSIZE		256		/* size of an mbuf */

#ifndef MCLSHIFT
#define	MCLSHIFT	11		/* convert bytes to m_buf clusters */
					/* 2K cluster can hold Ether frame */
#endif	/* MCLSHIFT */

#define	MCLBYTES	(1 << MCLSHIFT)	/* size of a m_buf cluster */

#ifndef NMBCLUSTERS_MAX
#define	NMBCLUSTERS_MAX	(0x4000000 / MCLBYTES)	/* Limit to 64MB for clusters */
#endif

#ifndef NFS_RSIZE
#define NFS_RSIZE	32768
#endif
#ifndef NFS_WSIZE
#define NFS_WSIZE	32768
#endif

/*
 * Minimum and maximum sizes of the kernel malloc arena in PAGE_SIZE-sized
 * logical pages.
 */
#define	NKMEMPAGES_MIN_DEFAULT	((16 * 1024 * 1024) >> PAGE_SHIFT)
#define	NKMEMPAGES_MAX_DEFAULT	((360 * 1024 * 1024) >> PAGE_SHIFT)

/*
 * Mach derived conversion macros
 */
#define	x86_round_pdr(x) \
	((((unsigned long)(x)) + (NBPD_L2 - 1)) & ~(NBPD_L2 - 1))
#define	x86_trunc_pdr(x)	((unsigned long)(x) & ~(NBPD_L2 - 1))
#define	x86_btod(x)		((unsigned long)(x) >> L2_SHIFT)
#define	x86_dtob(x)		((unsigned long)(x) << L2_SHIFT)
#define	x86_round_page(x)	((((paddr_t)(x)) + PGOFSET) & ~PGOFSET)
#define	x86_trunc_page(x)	((paddr_t)(x) & ~PGOFSET)
#define	x86_btop(x)		((paddr_t)(x) >> PGSHIFT)
#define	x86_ptob(x)		((paddr_t)(x) << PGSHIFT)

#endif /* _I386_PARAM_H_ */