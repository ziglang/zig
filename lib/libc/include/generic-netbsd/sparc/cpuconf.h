/*	$NetBSD: cpuconf.h,v 1.5 2016/10/08 20:30:54 joerg Exp $	*/

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

#ifndef _SPARC_CPUCONF_H_
#define	_SPARC_CPUCONF_H_

/*
 * Values for the cputyp variable.
 */
#define	CPU_SUN4	0
#define	CPU_SUN4C	1
#define	CPU_SUN4M	2
#define	CPU_SUN4U	3
#define	CPU_SUN4D	4

#if defined(_KERNEL) || defined(_STANDALONE)

#if defined(_KERNEL_OPT)
#include "opt_sparc_arch.h"
#endif /* _KERNEL_OPT */

#ifndef _LOCORE
extern int cputyp;
#endif

/* 
 * Shorthand CPU-type macros.  Let the compiler optimize away code
 * conditional on constants.
 */

/*
 * Step 1: Count the number of CPU types configured into the kernel.
 */
#if defined(_KERNEL_OPT)
#ifdef SUN4
#define	_CPU_NTYPES_SUN4 1
#else
#define	_CPU_NTYPES_SUN4 0
#endif
#ifdef SUN4C
#define	_CPU_NTYPES_SUN4C 1
#else
#define	_CPU_NTYPES_SUN4C 0
#endif
#ifdef SUN4M
#define	_CPU_NTYPES_SUN4M 1
#else
#define	_CPU_NTYPES_SUN4M 0
#endif
#ifdef SUN4D
#define	_CPU_NTYPES_SUN4D 1
#else
#define	_CPU_NTYPES_SUN4D 0
#endif
#define	CPU_NTYPES	(_CPU_NTYPES_SUN4 + _CPU_NTYPES_SUN4C + \
			 _CPU_NTYPES_SUN4M + _CPU_NTYPES_SUN4D)
#else
#define	CPU_NTYPES	0
#endif

/*
 * Step 2: Define the CPU type predicates.  Rules:
 *
 *	* If multiple CPU types are configured in, and the CPU type
 *	  is not one of them, then the test is always false.
 *
 *	* If exactly one CPU type is configured in, and it's this
 *	  one, then the test is always true.
 *
 *	* Otherwise, we have to reference the cputyp variable.
 */
#if CPU_NTYPES != 0 && !defined(SUN4)
#	define CPU_ISSUN4	(0)
#elif CPU_NTYPES == 1 && defined(SUN4)
#	define CPU_ISSUN4	(1)
#else
#	define CPU_ISSUN4	(cputyp == CPU_SUN4)
#endif 

#if CPU_NTYPES != 0 && !defined(SUN4C)
#	define CPU_ISSUN4C	(0)
#elif CPU_NTYPES == 1 && defined(SUN4C)
#	define CPU_ISSUN4C	(1)
#else
#	define CPU_ISSUN4C	(cputyp == CPU_SUN4C)
#endif

#if CPU_NTYPES != 0 && !defined(SUN4M)
#	define CPU_ISSUN4M	(0)
#elif CPU_NTYPES == 1 && defined(SUN4M) 
#	define CPU_ISSUN4M	(1)
#else                                   
#	define CPU_ISSUN4M	(cputyp == CPU_SUN4M)
#endif

#if CPU_NTYPES != 0 && !defined(SUN4D) 
#	define CPU_ISSUN4D	(0)
#elif CPU_NTYPES == 1 && defined(SUN4D)
#	define CPU_ISSUN4D	(1)
#else
#	define CPU_ISSUN4D	(cputyp == CPU_SUN4D)
#endif

#define	CPU_ISSUN4U		(0)

/*
 * Step 3: Define some short-hand for the different MMUs.
 */
#define	CPU_HAS_SRMMU		(CPU_ISSUN4M || CPU_ISSUN4D)
#define CPU_HAS_SUNMMU		(CPU_ISSUN4 || CPU_ISSUN4C)

#endif /* _KERNEL || _STANDALONE */

#endif /* _SPARC_CPUCONF_H_ */