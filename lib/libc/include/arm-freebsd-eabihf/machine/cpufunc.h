/*	$NetBSD: cpufunc.h,v 1.29 2003/09/06 09:08:35 rearnsha Exp $	*/

/*-
 * SPDX-License-Identifier: BSD-4-Clause
 *
 * Copyright (c) 1997 Mark Brinicombe.
 * Copyright (c) 1997 Causality Limited
 * All rights reserved.
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
 *	This product includes software developed by Causality Limited.
 * 4. The name of Causality Limited may not be used to endorse or promote
 *    products derived from this software without specific prior written
 *    permission.
 *
 * THIS SOFTWARE IS PROVIDED BY CAUSALITY LIMITED ``AS IS'' AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL CAUSALITY LIMITED BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * RiscBSD kernel project
 *
 * cpufunc.h
 *
 * Prototypes for cpu, mmu and tlb related functions.
 */

#ifndef _MACHINE_CPUFUNC_H_
#define _MACHINE_CPUFUNC_H_

#ifdef _KERNEL

#include <sys/types.h>
#include <machine/armreg.h>

static __inline void
breakpoint(void)
{
	__asm("udf        0xffff");
}

struct cpu_functions {
	/* CPU functions */
	void	(*cf_l2cache_wbinv_all) (void);
	void	(*cf_l2cache_wbinv_range) (vm_offset_t, vm_size_t);
	void	(*cf_l2cache_inv_range)	  (vm_offset_t, vm_size_t);
	void	(*cf_l2cache_wb_range)	  (vm_offset_t, vm_size_t);
	void	(*cf_l2cache_drain_writebuf)	  (void);

	/* Other functions */

	void	(*cf_sleep)		(int mode);

	void	(*cf_setup)		(void);
};

extern struct cpu_functions cpufuncs;
extern u_int cputype;

#define cpu_l2cache_wbinv_all()	cpufuncs.cf_l2cache_wbinv_all()
#define cpu_l2cache_wb_range(a, s) cpufuncs.cf_l2cache_wb_range((a), (s))
#define cpu_l2cache_inv_range(a, s) cpufuncs.cf_l2cache_inv_range((a), (s))
#define cpu_l2cache_wbinv_range(a, s) cpufuncs.cf_l2cache_wbinv_range((a), (s))
#define cpu_l2cache_drain_writebuf() cpufuncs.cf_l2cache_drain_writebuf()

#define cpu_sleep(m)		cpufuncs.cf_sleep(m)

#define cpu_setup()			cpufuncs.cf_setup()

int	set_cpufuncs		(void);
#define ARCHITECTURE_NOT_PRESENT	1	/* known but not configured */

void	cpufunc_nullop		(void);
u_int	cpufunc_control		(u_int clear, u_int bic);


#if defined(CPU_CORTEXA) || defined(CPU_MV_PJ4B) || defined(CPU_KRAIT)
void	armv7_cpu_sleep			(int);
#endif
#if defined(CPU_MV_PJ4B)
void	pj4b_config			(void);
#endif

#if defined(CPU_ARM1176)
void    arm11x6_sleep                   (int);  /* no ref. for errata */
#endif


/*
 * Macros for manipulating CPU interrupts
 */
#define	__ARM_INTR_BITS		(PSR_I | PSR_F | PSR_A)

static __inline uint32_t
__set_cpsr(uint32_t bic, uint32_t eor)
{
	uint32_t	tmp, ret;

	__asm __volatile(
		"mrs     %0, cpsr\n"		/* Get the CPSR */
		"bic	 %1, %0, %2\n"		/* Clear bits */
		"eor	 %1, %1, %3\n"		/* XOR bits */
		"msr     cpsr_xc, %1\n"		/* Set the CPSR */
	: "=&r" (ret), "=&r" (tmp)
	: "r" (bic), "r" (eor) : "memory");

	return ret;
}

static __inline uint32_t
disable_interrupts(uint32_t mask)
{

	return (__set_cpsr(mask & __ARM_INTR_BITS, mask & __ARM_INTR_BITS));
}

static __inline uint32_t
enable_interrupts(uint32_t mask)
{

	return (__set_cpsr(mask & __ARM_INTR_BITS, 0));
}

static __inline uint32_t
restore_interrupts(uint32_t old_cpsr)
{

	return (__set_cpsr(__ARM_INTR_BITS, old_cpsr & __ARM_INTR_BITS));
}

static __inline register_t
intr_disable(void)
{

	return (disable_interrupts(PSR_I | PSR_F));
}

static __inline void
intr_restore(register_t s)
{

	restore_interrupts(s);
}
#undef __ARM_INTR_BITS

/*
 * Functions to manipulate cpu r13
 * (in arm/arm32/setstack.S)
 */

void set_stackptr	(u_int mode, u_int address);
u_int get_stackptr	(u_int mode);

/*
 * CPU functions from locore.S
 */

void cpu_reset		(void) __attribute__((__noreturn__));

/*
 * Cache info variables.
 */

/* PRIMARY CACHE VARIABLES */
extern unsigned int	arm_dcache_align;
extern unsigned int	arm_dcache_align_mask;

#else	/* !_KERNEL */

static __inline void
breakpoint(void)
{

	/*
	 * This matches the instruction used by GDB for software
	 * breakpoints.
	 */
	__asm("udf        0xfdee");
}

#endif	/* _KERNEL */
#endif	/* _MACHINE_CPUFUNC_H_ */

/* End of cpufunc.h */