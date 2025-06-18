/*-
 * Copyright (c) 2015-2018 Ruslan Bukin <br@bsdpad.com>
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

#ifndef _MACHINE_CPU_H_
#define	_MACHINE_CPU_H_

#include <machine/atomic.h>
#include <machine/cpufunc.h>
#include <machine/frame.h>

#define	TRAPF_PC(tfp)		((tfp)->tf_sepc)
#define	TRAPF_USERMODE(tfp)	(((tfp)->tf_sstatus & SSTATUS_SPP) == 0)

#define	cpu_getstack(td)	((td)->td_frame->tf_sp)
#define	cpu_setstack(td, sp)	((td)->td_frame->tf_sp = (sp))
#define	cpu_spinwait()		/* nothing */
#define	cpu_lock_delay()	DELAY(1)

#ifdef _KERNEL

/*
 * Core manufacturer IDs, as reported by the mvendorid CSR.
 */
#define	MVENDORID_UNIMPL	0x0
#define	MVENDORID_SIFIVE	0x489
#define	MVENDORID_THEAD		0x5b7

/*
 * Micro-architecture ID register, marchid.
 *
 * IDs for open-source implementations are allocated globally. Commercial IDs
 * will have the most-significant bit set.
 */
#define	MARCHID_UNIMPL		0x0
#define	MARCHID_MSB		(1ul << (XLEN - 1))
#define	MARCHID_OPENSOURCE(v)	(v)
#define	MARCHID_COMMERCIAL(v)	(MARCHID_MSB | (v))
#define	MARCHID_IS_OPENSOURCE(m) (((m) & MARCHID_MSB) == 0)

/*
 * Open-source marchid values.
 *
 * https://github.com/riscv/riscv-isa-manual/blob/master/marchid.md
 */
#define	MARCHID_UCB_ROCKET	MARCHID_OPENSOURCE(1)
#define	MARCHID_UCB_BOOM	MARCHID_OPENSOURCE(2)
#define	MARCHID_UCB_SPIKE	MARCHID_OPENSOURCE(5)
#define	MARCHID_UCAM_RVBS	MARCHID_OPENSOURCE(10)

/* SiFive marchid values */
#define	MARCHID_SIFIVE_U7	MARCHID_COMMERCIAL(7)

/*
 * MMU virtual-addressing modes. Support for each level implies the previous,
 * so Sv48-enabled systems MUST support Sv39, etc.
 */
#define	MMU_SV39	0x1	/* 3-level paging */
#define	MMU_SV48	0x2	/* 4-level paging */
#define	MMU_SV57	0x4	/* 5-level paging */

extern char btext[];
extern char etext[];

void	cpu_halt(void) __dead2;
void	cpu_reset(void) __dead2;
void	fork_trampoline(void);
void	identify_cpu(u_int cpu);
void	printcpuinfo(u_int cpu);

static __inline uint64_t
get_cyclecount(void)
{

	return (rdcycle());
}

#endif

#endif /* !_MACHINE_CPU_H_ */