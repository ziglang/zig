/*-
 * Copyright (c) 2015-2016 Ruslan Bukin <br@bsdpad.com>
 * All rights reserved.
 *
 * Portions of this software were developed by SRI International and the
 * University of Cambridge Computer Laboratory under DARPA/AFRL contract
 * FA8750-10-C-0237 ("CTSRD"), as part of the DARPA CRASH research programme.
 *
 * Portions of this software were developed by the University of Cambridge
 * Computer Laboratory as part of the CTSRD Project, with support from the
 * UK Higher Education Innovation Fund (HEIF).
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _MACHINE_CPUFUNC_H_
#define	_MACHINE_CPUFUNC_H_

static __inline void
breakpoint(void)
{

	__asm("ebreak");
}

#ifdef _KERNEL

#include <machine/riscvreg.h>

static __inline register_t
intr_disable(void)
{
	uint64_t ret;

	__asm __volatile(
		"csrrci %0, sstatus, %1"
		: "=&r" (ret) : "i" (SSTATUS_SIE)
	);

	return (ret & (SSTATUS_SIE));
}

static __inline void
intr_restore(register_t s)
{

	__asm __volatile(
		"csrs sstatus, %0"
		:: "r" (s)
	);
}

static __inline void
intr_enable(void)
{

	__asm __volatile(
		"csrsi sstatus, %0"
		:: "i" (SSTATUS_SIE)
	);
}

/* NB: fence() is defined as a macro in <machine/atomic.h>. */

static __inline void
fence_i(void)
{

	__asm __volatile("fence.i" ::: "memory");
}

static __inline void
sfence_vma(void)
{

	__asm __volatile("sfence.vma" ::: "memory");
}

static __inline void
sfence_vma_page(uintptr_t addr)
{

	__asm __volatile("sfence.vma %0" :: "r" (addr) : "memory");
}

#define	rdcycle()			csr_read64(cycle)
#define	rdtime()			csr_read64(time)
#define	rdinstret()			csr_read64(instret)
#define	rdhpmcounter(n)			csr_read64(hpmcounter##n)

extern int64_t dcache_line_size;
extern int64_t icache_line_size;

#define	cpu_dcache_wbinv_range(a, s)
#define	cpu_dcache_inv_range(a, s)
#define	cpu_dcache_wb_range(a, s)

#define	cpu_idcache_wbinv_range(a, s)
#define	cpu_icache_sync_range(a, s)
#define	cpu_icache_sync_range_checked(a, s)

#define	cpufunc_nullop()		riscv_nullop()

void riscv_nullop(void);

#endif	/* _KERNEL */
#endif	/* _MACHINE_CPUFUNC_H_ */