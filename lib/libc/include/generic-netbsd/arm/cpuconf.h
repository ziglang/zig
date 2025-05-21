/*	$NetBSD: cpuconf.h,v 1.28 2020/09/29 19:58:50 jmcneill Exp $	*/

/*
 * Copyright (c) 2002 Wasabi Systems, Inc.
 * All rights reserved.
 *
 * Written by Jason R. Thorpe for Wasabi Systems, Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed for the NetBSD Project by
 *	Wasabi Systems, Inc.
 * 4. The name of Wasabi Systems, Inc. may not be used to endorse
 *    or promote products derived from this software without specific prior
 *    written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY WASABI SYSTEMS, INC. ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL WASABI SYSTEMS, INC
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _ARM_CPUCONF_H_
#define	_ARM_CPUCONF_H_

#if defined(_KERNEL_OPT)
#include "opt_cputypes.h"
#include "opt_cpuoptions.h"
#endif /* _KERNEL_OPT */

#if defined(CPU_XSCALE_PXA250) || defined(CPU_XSCALE_PXA270)
#define	__CPU_XSCALE_PXA2XX
#endif

#ifdef CPU_XSCALE_PXA2X0
#warning option CPU_XSCALE_PXA2X0 is obsolete. Use CPU_XSCALE_PXA250 and/or CPU_XSCALE_PXA270.
#endif

/*
 * IF YOU CHANGE THIS FILE, MAKE SURE TO UPDATE THE DEFINITION OF
 * "PMAP_NEEDS_PTE_SYNC" IN <arm/arm32/pmap.h> FOR THE CPU TYPE
 * YOU ARE ADDING SUPPORT FOR.
 */

#if 0
/*
 * Step 1: Count the number of CPU types configured into the kernel.
 */
#if defined(_KERNEL_OPT)
#define	CPU_NTYPES	(defined(CPU_ARM6) + defined(CPU_ARM7) +	\
			 defined(CPU_ARM7TDMI) +			\
			 defined(CPU_ARM8) + defined(CPU_ARM9) +	\
			 defined(CPU_ARM9E) +				\
			 defined(CPU_ARM10) +				\
			 defined(CPU_ARM11) +				\
			 defined(CPU_ARM1136) +				\
			 defined(CPU_ARM1176) +				\
			 defined(CPU_ARM11MPCORE) +			\
			 defined(CPU_CORTEX) +				\
			 defined(CPU_SA110) + defined(CPU_SA1100) +	\
			 defined(CPU_SA1110) +				\
			 defined(CPU_FA526) +				\
			 defined(CPU_IXP12X0) +				\
			 defined(CPU_XSCALE) +				\
			 defined(CPU_SHEEVA))
#else
#define	CPU_NTYPES	2
#endif /* _KERNEL_OPT */
#endif

/*
 * Step 2: Determine which ARM architecture versions are configured.
 */
#if !defined(_KERNEL_OPT)
#define	ARM_ARCH_2	1
#else
#define	ARM_ARCH_2	0
#endif

#if !defined(_KERNEL_OPT) ||						\
    (defined(CPU_ARM6) || defined(CPU_ARM7))
#define	ARM_ARCH_3	1
#else
#define	ARM_ARCH_3	0
#endif

#if !defined(_KERNEL_OPT) ||						\
    (defined(CPU_ARM7TDMI) || defined(CPU_ARM8) || defined(CPU_ARM9) ||	\
     defined(CPU_SA110) || defined(CPU_SA1100) || defined(CPU_FA526) || \
     defined(CPU_SA1110) || defined(CPU_IXP12X0))
#define	ARM_ARCH_4	1
#else
#define	ARM_ARCH_4	0
#endif

#if !defined(_KERNEL_OPT) ||						\
    (defined(CPU_ARM9E) || defined(CPU_ARM10) ||			\
     defined(CPU_XSCALE) || defined(CPU_SHEEVA))
#define	ARM_ARCH_5	1
#else
#define	ARM_ARCH_5	0
#endif

#if defined(CPU_ARM11) || defined(CPU_ARM11MPCORE)
#define ARM_ARCH_6	1
#else
#define ARM_ARCH_6	0
#endif

#if defined(CPU_CORTEX) || defined(CPU_PJ4B)
#define ARM_ARCH_7	1
#else
#define ARM_ARCH_7	0
#endif

#define	ARM_NARCH	(ARM_ARCH_2 + ARM_ARCH_3 + ARM_ARCH_4 + \
			 ARM_ARCH_5 + ARM_ARCH_6 + ARM_ARCH_7)
#if ARM_NARCH == 0
#error ARM_NARCH is 0
#endif

#if ARM_ARCH_5 || ARM_ARCH_6 || ARM_ARCH_7
/*
 * We could support Thumb code on v4T, but the lack of clean interworking
 * makes that hard.
 */
#define THUMB_CODE
#endif

/*
 * Step 3: Define which MMU classes are configured:
 *
 *	ARM_MMU_MEMC		Prehistoric, external memory controller
 *				and MMU for ARMv2 CPUs.
 *
 *	ARM_MMU_GENERIC		Generic ARM MMU, compatible with ARM6.
 *
 *	ARM_MMU_SA1		StrongARM SA-1 MMU.  Compatible with generic
 *				ARM MMU, but has no write-through cache mode.
 *
 *	ARM_MMU_XSCALE		XScale MMU.  Compatible with generic ARM
 *				MMU, but also has several extensions which
 *				require different PTE layout to use.
 *
 *	ARM_MMU_V6C		ARM v6 MMU in backward compatible mode.
 *                              Compatible with generic ARM MMU, but
 *                              also has several extensions which
 *				require different PTE layouts to use.
 *                              XP bit in CP15 control reg is cleared.
 *
 *	ARM_MMU_V6N		ARM v6 MMU with XP bit of CP15 control reg
 *                              set.  New features such as shared-bit
 *                              and excute-never bit are available.
 *                              Multiprocessor support needs this mode.
 *
 *	ARM_MMU_V7		ARM v7 MMU.
 */
#if !defined(_KERNEL_OPT)
#define	ARM_MMU_MEMC		1
#else
#define	ARM_MMU_MEMC		0
#endif

#if !defined(_KERNEL_OPT) ||						\
    (defined(CPU_ARM6) || defined(CPU_ARM7) || defined(CPU_ARM7TDMI) ||	\
     defined(CPU_ARM8) || defined(CPU_ARM9) || defined(CPU_ARM9E) ||	\
     defined(CPU_ARM10) || defined(CPU_FA526)) || defined(CPU_SHEEVA)
#define	ARM_MMU_GENERIC		1
#else
#define	ARM_MMU_GENERIC		0
#endif

#if !defined(_KERNEL_OPT) ||						\
    (defined(CPU_SA110) || defined(CPU_SA1100) || defined(CPU_SA1110) ||\
     defined(CPU_IXP12X0))
#define	ARM_MMU_SA1		1
#else
#define	ARM_MMU_SA1		0
#endif

#if !defined(_KERNEL_OPT) ||						\
    defined(CPU_XSCALE)
#define	ARM_MMU_XSCALE		1
#else
#define	ARM_MMU_XSCALE		0
#endif

#if !defined(_KERNEL_OPT) ||						\
	(defined(CPU_ARM11) && defined(ARM11_COMPAT_MMU))
#define	ARM_MMU_V6C		1
#else
#define	ARM_MMU_V6C		0
#endif

#if !defined(_KERNEL_OPT) ||						\
	(defined(CPU_ARM11) && !defined(ARM11_COMPAT_MMU))
#define	ARM_MMU_V6N		1
#else
#define	ARM_MMU_V6N		0
#endif

#define	ARM_MMU_V6	(ARM_MMU_V6C + ARM_MMU_V6N)

#if !defined(_KERNEL_OPT) ||						\
	 defined(CPU_ARMV7)
#define	ARM_MMU_V7		1
#else
#define	ARM_MMU_V7		0
#endif

#if !defined(_KERNEL_OPT) ||						\
	 defined(CPU_ARMV8)
#define	ARM_MMU_V8		1
#else
#define	ARM_MMU_V8		0
#endif

/*
 * Can we use the ASID support in armv6+ MMUs?
 */
#if !defined(_LOCORE)
#define	ARM_MMU_EXTENDED						\
    ((ARM_MMU_MEMC + ARM_MMU_GENERIC + ARM_MMU_SA1 + ARM_MMU_XSCALE +	\
     ARM_MMU_V6C) == 0 &&						\
    (ARM_MMU_V6N + ARM_MMU_V7 + ARM_MMU_V8) > 0)
#if ARM_MMU_EXTENDED == 0
#undef ARM_MMU_EXTENDED
#endif
#endif

#define	ARM_NMMUS							\
    (ARM_MMU_MEMC + ARM_MMU_GENERIC + ARM_MMU_SA1 + ARM_MMU_XSCALE +	\
     ARM_MMU_V6N + ARM_MMU_V6C + ARM_MMU_V7 + ARM_MMU_V8)
#if ARM_NMMUS == 0
#error ARM_NMMUS is 0
#endif

/*
 * Step 4: Define features that may be present on a subset of CPUs
 *
 *	ARM_XSCALE_PMU		Performance Monitoring Unit on 80200 and 80321
 */

#if !defined(_KERNEL_OPT) ||						\
    (defined(CPU_XSCALE_80200) || defined(CPU_XSCALE_80321))
#define ARM_XSCALE_PMU	1
#else
#define ARM_XSCALE_PMU	0
#endif

#endif /* _ARM_CPUCONF_H_ */