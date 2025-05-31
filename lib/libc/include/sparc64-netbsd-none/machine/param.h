/*	$NetBSD: param.h,v 1.62 2021/05/31 14:38:56 simonb Exp $ */

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
 *	@(#)param.h	8.1 (Berkeley) 6/11/93
 */

/*
 * Copyright (c) 1996-2002 Eduardo Horvath
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *  
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR  ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR  BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 */

#if defined(_KERNEL_OPT)
#include "opt_param.h"
#include "opt_sparc_arch.h"
#endif

#ifdef __arch64__
#define	_MACHINE	sparc64
#define	MACHINE		"sparc64"
#define	_MACHINE_ARCH	sparc64
#define	MACHINE_ARCH	"sparc64"
#define	MID_MACHINE	MID_SPARC64
#else
#define	_MACHINE	sparc
#define	MACHINE		"sparc"
#define	_MACHINE_ARCH	sparc
#define	MACHINE_ARCH	"sparc"
#define	MID_MACHINE	MID_SPARC
#endif

#ifdef _KERNEL				/* XXX */
#ifndef _LOCORE				/* XXX */
#include <machine/cpu.h>		/* XXX */
#endif					/* XXX */
#endif					/* XXX */

#define ALIGNBYTES32		0x7
#define ALIGNBYTES64		0xf
#define ALIGN32(p)		(((u_long)(p) + ALIGNBYTES32) & ~ALIGNBYTES32)


/*
 * The following variables are always defined and initialized (in locore)
 * so independently compiled modules (e.g. LKMs) can be used irrespective
 * of the `options SUN4?' combination a particular kernel was configured with.
 * See also the definitions of NBPG, PGOFSET and PGSHIFT below.
 */
#if (defined(_KERNEL) || defined(_STANDALONE)) && !defined(_LOCORE)
extern int nbpg, pgofset, pgshift;
#endif

#ifdef __arch64__

#ifdef SUN4V
#define	MAXCPUS		256
#endif

/* We get stack overflows w/8K stacks in 64-bit mode */
#define	SSIZE		2		/* initial stack size in pages */
#else
#define	SSIZE		2
#endif
#define	USPACE		(SSIZE*8192)


/*
 * Here are all the magic kernel virtual addresses and how they're allocated.
 * 
 * First, the PROM is usually a fixed-sized block from 0x00000000f0000000 to
 * 0x00000000f0100000.  It also uses some space around 0x00000000fff00000 to
 * map in device registers.  The rest is pretty much ours to play with.
 *
 * The kernel starts at KERNBASE.  Here's the layout.  We use macros to set
 * the addresses so we can relocate everything easily.  We use 4MB locked TTEs
 * to map in the kernel text and data segments.  Any extra pages are recycled,
 * so they can potentially be double-mapped.  This shouldn't really be a
 * problem since they're unused, but wild pointers can cause silent data
 * corruption if they are in those segments.
 *
 * 0x0000000000000000:	64K NFO page zero
 * 0x0000000000010000:	Userland or PROM
 * KERNBASE:		4MB (or multiple thereof) kernel text and read only
 *			        data. This is mapped in the ITLB and 
 *				Read-Only in the DTLB
 * KERNBASE+0x400000:	4MB kernel data and BSS -- not in ITLB
 *				Contains context table, kernel pmap,
 *				and other important structures.
 * KERNBASE+0x800000:	Unmapped page -- redzone
 * KERNBASE+0x802000:	Process 0 stack and u-area
 * KERNBASE+0x806000:	2 pages for pmap_copy_page and /dev/mem
 *
 * For 32 bit kernels:
 *  KERNBASE+0x80a000:	Start of kernel VA segment
 *  KERNEND:		End of kernel VA segment
 *
 * KERNEND+0x02000:	Auxreg_va (unused?)
 * KERNEND+0x04000:	TMPMAP_VA (unused?)
 * KERNEND+0x06000:	message buffer.
 * KERNEND+0x010000:	INTSTACK -- per-cpu 64K locked TTE
 *			Contains interrupt stack (32KB), cpu_info structure
 *			and panicstack (32KB)
 * KERNEND+0x018000:	CPUINFO_VA -- cpu_info structure
 * KERNEND+0x020000:	unmapped space (top of panicstack)
 * KERNEND+0x022000:	IODEV_BASE -- begin mapping IO devices here.
 * 0x00000000f0000000:	IODEV_END -- end of device mapping space.
 *
 * For 64 bit kernels:
 *  0x100000000:	Start of kernel VA segment (theoretically upto
 *			the VA hole)
 *
 */
#define	KERNBASE	0x001000000	/* start of kernel virtual space */
#define	KERNEND		0x0e0000000	/* end of kernel virtual space */

#define	_MAXNBPG	8192	/* fixed VAs, independent of actual NBPG */

#define	MSGBUF_VA	(      KERNEND + _MAXNBPG) /* 1 page REDZONE */
/*
 * Maximum message buffer size is 248k.
 * Here's the location of the interrupt stack and CPU structure.
 */
#define	INTSTACK	(      KERNEND + 32*_MAXNBPG)
#define	EINTSTACK	(     INTSTACK + 4*_MAXNBPG)
#define	CPUINFO_VA	(    EINTSTACK              )
#define	PANICSTACK	(     INTSTACK + 8*_MAXNBPG)
#define	IODEV_BASE	(     INTSTACK + 9*_MAXNBPG)	/* 1 page redzone */
#define	IODEV_END	0x0f0000000UL			/* ~16 MB of iospace */

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

#if !defined (MSGBUFSIZE)		/* options MSGBUFSIZE=integer	*/
#define MSGBUFSIZE	(4 * NBPG)
#else
#if INTSTACK - MSGBUF_VA - MSGBUFSIZE < 0
#error MSGBUFSIZE is too large
#endif
#endif

/*
 * Minimum size of the kernel kmem_arena in PAGE_SIZE-sized
 * logical pages.
 * For 32bit kernels:
 * Maximum of 2.5GB on sparc64 (it must fit into KERNEND - KERNBASE, and also
 * leave space in the kernel_map for other allocations).
 * For 64bit kernels:
 * Unlimited. (Practically there is a limit, we use VA starting at 4GB upto
 * the VA-hole, but let us call this unlimited for now.)
 */
#define	NKMEMPAGES_MIN_DEFAULT	((64 * 1024 * 1024) >> PAGE_SHIFT)
#ifdef __arch64__
#define	NKMEMPAGES_MAX_UNLIMITED
#else
#undef	NKMEMPAGES_MAX_UNLIMITED
#define	NKMEMPAGES_MAX_DEFAULT	((2048UL * 1024 * 1024) >> PAGE_SHIFT)
#endif

#ifdef _KERNEL
#ifndef _LOCORE

#ifndef __HIDE_DELAY
extern void	delay(unsigned int);
#define	DELAY(n)	delay(n)
#endif /* __HIDE_DELAY */

/* Keep this a const so compiler optimization is done */
extern const int cputyp;

#if defined (SUN4US) || defined (SUN4V)
#define CPU_ISSUN4U     (cputyp == CPU_SUN4U)
#define CPU_ISSUN4US    (cputyp == CPU_SUN4US)
#define CPU_ISSUN4V     (cputyp == CPU_SUN4V)
#else
#define CPU_ISSUN4U	(1)
#define CPU_ISSUN4US	(0)
#define CPU_ISSUN4V	(0)
#endif

#endif /* _LOCORE */
#endif /* _KERNEL */

/*
 * Values for the cputyp variable.
 */
#define CPU_SUN4	0
#define CPU_SUN4C	1
#define CPU_SUN4M	2
#define CPU_SUN4U	3
#define CPU_SUN4US	4
#define CPU_SUN4V	5

/*
 * Shorthand CPU-type macros. Enumerate all eight cases.
 * Let compiler optimize away code conditional on constants.
 *
 * On a sun4 machine, the page size is 8192, while on a sun4c and sun4m
 * it is 4096. Therefore, in the (SUN4 && (SUN4C || SUN4M)) cases below,
 * NBPG, PGOFSET and PGSHIFT are defined as variables which are initialized
 * early in locore.s after the machine type has been detected.
 *
 * Note that whenever the macros defined below evaluate to expressions
 * involving variables, the kernel will perform slightly worse due to the
 * extra memory references they'll generate.
 */

#define CPU_ISSUN4M	(0)
#define CPU_ISSUN4C	(0)
#define CPU_ISSUN4	(0)


#define	PGSHIFT		13		/* log2(NBPG) */
#define	NBPG		(1<<PGSHIFT)	/* bytes/page */
#define	PGOFSET		(NBPG-1)	/* byte offset into page */

#define PCI_MAGIC_IO_RANGE	0x100000000LL