/*	$NetBSD: param.h,v 1.74 2020/05/01 08:21:27 isaki Exp $ */

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
 * Sun4M support by Aaron Brown, Harvard University.
 * Changes Copyright (c) 1995 The President and Fellows of Harvard College.
 * All rights reserved.
 */
#define	_MACHINE	sparc
#define	MACHINE		"sparc"
#define	_MACHINE_ARCH	sparc
#define	MACHINE_ARCH	"sparc"
#define	MID_MACHINE	MID_SPARC

#include <machine/cpuconf.h>		/* XXX */
#ifdef _KERNEL				/* XXX */
#ifndef _LOCORE				/* XXX */
#include <machine/cpu.h>		/* XXX */
#endif					/* XXX */
#endif					/* XXX */

#define SUN4_PGSHIFT	13	/* for a sun4 machine */
#define SUN4CM_PGSHIFT	12	/* for a sun4c or sun4m machine */

/*
 * The following variables are always defined and initialized (in locore)
 * so independently compiled modules (e.g. LKMs) can be used irrespective
 * of the `options SUN4?' combination a particular kernel was configured with.
 * See also the definitions of NBPG, PGOFSET and PGSHIFT below.
 */
#if (defined(_KERNEL) || defined(_STANDALONE)) && !defined(_LOCORE)
extern int nbpg, pgofset, pgshift;
#endif

#if !(defined(PROM_AT_F0) || defined(MSIIEP))
#define	KERNBASE	0xf0000000	/* start of kernel virtual space */
#else
/*
 * JS1/OF has prom sitting in f000.0000..f007.ffff, modify kernel VA 
 * layout to work around that. XXX - kernel should live beyound prom on
 * those machines.
 */
#define	KERNBASE	0xe8000000
#endif
#define KERNEND		0xfe000000	/* end of kernel virtual space */
#define PROM_LOADADDR	0x00004000	/* where the prom loads us */
#define	KERNTEXTOFF	(KERNBASE+PROM_LOADADDR)/* start of kernel text */

#define	SSIZE		1		/* initial stack size in pages */
#define	USPACE		8192

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

/*
 * Minimum and maximum sizes of the kernel malloc arena in PAGE_SIZE-sized
 * logical pages.
 */
#define	NKMEMPAGES_MIN_DEFAULT	((16 * 1024 * 1024) >> PAGE_SHIFT)
#define	NKMEMPAGES_MAX_DEFAULT	((128 * 1024 * 1024) >> PAGE_SHIFT)

#if defined(_KERNEL) || defined(_STANDALONE)
#ifndef _LOCORE

#ifndef __HIDE_DELAY
extern void	delay(unsigned int);
#define	DELAY(n)	delay(n)
#endif /* __HIDE_DELAY */

#endif /* _LOCORE */

/*
 * microSPARC-IIep is a sun4m but with an integrated PCI controller.
 * In a lot of places (like pmap &c) we want it to be treated as SUN4M.
 * But since various low-level things are done very differently from
 * normal sparcs (and since for now it requires a relocated kernel
 * anyway), the MSIIEP kernels are not supposed to support any other
 * system.  So insist on SUN4M defined and SUN4 and SUN4C not defined.
 */
#if defined(MSIIEP)
#if defined(SUN4) || defined(SUN4C) || defined(SUN4D)
#error "microSPARC-IIep kernels cannot support sun4, sun4c, or sun4d"
#endif
#if !defined(SUN4M)
#error "microSPARC-IIep kernel must have 'options SUN4M'"
#endif
#endif /* MSIIEP */

/*
 * Sun4 machines have a page size of 8192.  All other machines have a page
 * size of 4096.  Short cut page size variables if we can.
 */
#if CPU_NTYPES != 0 && !defined(SUN4)
#	define NBPG		4096
#	define PGOFSET		(NBPG-1)
#	define PGSHIFT		SUN4CM_PGSHIFT
#elif CPU_NTYPES == 1 && defined(SUN4)
#	define NBPG		8192
#	define PGOFSET		(NBPG-1)
#	define PGSHIFT		SUN4_PGSHIFT
#else
#	define NBPG		nbpg
#	define PGOFSET		pgofset
#	define PGSHIFT		pgshift
#endif

/* Default audio blocksize in msec.  See sys/dev/audio/audio.c */
#define	__AUDIO_BLK_MS (40)

#endif /* _KERNEL || _STANDALONE */