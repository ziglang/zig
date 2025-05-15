/*-
 * Copyright (c) 1999 Luoqi Chen <luoqi@freebsd.org>
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
 *
 *	from: FreeBSD: src/sys/i386/include/globaldata.h,v 1.27 2001/04/27
 */

#ifdef __arm__
#include <arm/pcpu.h>
#else /* !__arm__ */

#ifndef	_MACHINE_PCPU_H_
#define	_MACHINE_PCPU_H_

#include <machine/cpu.h>
#include <machine/cpufunc.h>

typedef int (*pcpu_bp_harden)(void);
typedef int (*pcpu_ssbd)(int);
struct debug_monitor_state;

#define	PCPU_MD_FIELDS							\
	u_int	pc_acpi_id;	/* ACPI CPU id */			\
	u_int	pc_midr;	/* stored MIDR value */			\
	uint64_t pc_clock;						\
	pcpu_bp_harden pc_bp_harden;					\
	pcpu_ssbd pc_ssbd;						\
	struct pmap *pc_curpmap;					\
	struct pmap *pc_curvmpmap;					\
	/* Store as two u_int values to preserve KBI */			\
	uint64_t pc_mpidr;						\
	u_int	pc_bcast_tlbi_workaround;				\
	char __pad[197]

#ifdef _KERNEL

struct pcb;
struct pcpu;

register struct pcpu *pcpup __asm ("x18");

static inline struct pcpu *
get_pcpu(void)
{
	struct pcpu *pcpu;

	__asm __volatile("mov   %0, x18" : "=&r"(pcpu));
	return (pcpu);
}

static inline struct thread *
get_curthread(void)
{
	struct thread *td;

	__asm __volatile("ldr	%0, [x18]" : "=&r"(td));
	return (td);
}

#define	curthread get_curthread()

#define	PCPU_GET(member)	(pcpup->pc_ ## member)
#define	PCPU_ADD(member, value)	(pcpup->pc_ ## member += (value))
#define	PCPU_PTR(member)	(&pcpup->pc_ ## member)
#define	PCPU_SET(member,value)	(pcpup->pc_ ## member = (value))

#define	PCPU_GET_MPIDR(pc)	((pc)->pc_mpidr)

#endif	/* _KERNEL */

#endif	/* !_MACHINE_PCPU_H_ */

#endif /* !__arm__ */