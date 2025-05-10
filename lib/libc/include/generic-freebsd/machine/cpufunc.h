/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 1998 Doug Rabson
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

#ifdef _KERNEL

#include <sys/types.h>

#include <machine/psl.h>
#include <machine/spr.h>

struct thread;

#ifdef KDB
void breakpoint(void);
#else
static __inline void
breakpoint(void)
{

	return;
}
#endif

/* CPU register mangling inlines */

static __inline void
mtmsr(register_t value)
{

	__asm __volatile ("mtmsr %0; isync" :: "r"(value));
}

#ifdef __powerpc64__
static __inline void
mtmsrd(register_t value)
{

	__asm __volatile ("mtmsrd %0; isync" :: "r"(value));
}
#endif

static __inline register_t
mfmsr(void)
{
	register_t value;

	__asm __volatile ("mfmsr %0" : "=r"(value));

	return (value);
}

#ifndef __powerpc64__
static __inline void
mtsrin(vm_offset_t va, register_t value)
{

	__asm __volatile ("mtsrin %0,%1; isync" :: "r"(value), "r"(va));
}

static __inline register_t
mfsrin(vm_offset_t va)
{
	register_t value;

	__asm __volatile ("mfsrin %0,%1" : "=r"(value) : "r"(va));

	return (value);
}
#endif

static __inline register_t
mfctrl(void)
{
	register_t value;

	__asm __volatile ("mfspr %0,136" : "=r"(value));

	return (value);
}

static __inline void
mtdec(register_t value)
{

	__asm __volatile ("mtdec %0" :: "r"(value));
}

static __inline register_t
mfdec(void)
{
	register_t value;

	__asm __volatile ("mfdec %0" : "=r"(value));

	return (value);
}

static __inline uint32_t
mfpvr(void)
{
	uint32_t value;

	__asm __volatile ("mfpvr %0" : "=r"(value));

	return (value);
}

static __inline u_quad_t
mftb(void)
{
	u_quad_t tb;
      #ifdef __powerpc64__
	__asm __volatile ("mftb %0" : "=r"(tb));
      #else
	uint32_t *tbup = (uint32_t *)&tb;
	uint32_t *tblp = tbup + 1;

	do {
		*tbup = mfspr(TBR_TBU);
		*tblp = mfspr(TBR_TBL);
	} while (*tbup != mfspr(TBR_TBU));
      #endif

	return (tb);
}

static __inline void
mttb(u_quad_t time)
{

	mtspr(TBR_TBWL, 0);
	mtspr(TBR_TBWU, (uint32_t)(time >> 32));
	mtspr(TBR_TBWL, (uint32_t)(time & 0xffffffff));
}

static __inline register_t
mffs(void)
{
	uint64_t value;

	__asm __volatile ("mffs 0; stfd 0,0(%0)"
			:: "b"(&value));

	return ((register_t)value);
}

static __inline void
mtfsf(uint64_t value)
{

	__asm __volatile ("lfd 0,0(%0); mtfsf 0xff,0"
			:: "b"(&value));
}

static __inline void
eieio(void)
{

	__asm __volatile ("eieio" : : : "memory");
}

static __inline void
isync(void)
{

	__asm __volatile ("isync" : : : "memory");
}

static __inline void
powerpc_sync(void)
{

	__asm __volatile ("sync" : : : "memory");
}

static __inline int
cntlzd(uint64_t word)
{
	uint64_t result;
	/* cntlzd %0, %1 */
	__asm __volatile(".long 0x7c000074 |  (%1 << 21) | (%0 << 16)" :
	    "=r"(result) : "r"(word));

	return (int)result;
}

static __inline int
cnttzd(uint64_t word)
{
	uint64_t result;
	/* cnttzd %0, %1 */
	__asm __volatile(".long 0x7c000474 |  (%1 << 21) | (%0 << 16)" :
	    "=r"(result) : "r"(word));

	return (int)result;
}

static __inline void
ptesync(void)
{
	__asm __volatile("ptesync");
}

static __inline register_t
intr_disable(void)
{
	register_t msr;

	msr = mfmsr();
	mtmsr(msr & ~PSL_EE);
	return (msr);
}

static __inline void
intr_restore(register_t msr)
{

	mtmsr(msr);
}

static __inline struct pcpu *
get_pcpu(void)
{
	struct pcpu *ret;

	__asm __volatile("mfsprg %0, 0" : "=r"(ret));

	return (ret);
}

/* "NOP" operations to signify priorities to the kernel. */
static __inline void
nop_prio_vlow(void)
{
	__asm __volatile("or 31,31,31");
}

static __inline void
nop_prio_low(void)
{
	__asm __volatile("or 1,1,1");
}

static __inline void
nop_prio_mlow(void)
{
	__asm __volatile("or 6,6,6");
}

static __inline void
nop_prio_medium(void)
{
	__asm __volatile("or 2,2,2");
}

static __inline void
nop_prio_mhigh(void)
{
	__asm __volatile("or 5,5,5");
}

static __inline void
nop_prio_high(void)
{
	__asm __volatile("or 3,3,3");
}

#endif /* _KERNEL */

#endif /* !_MACHINE_CPUFUNC_H_ */