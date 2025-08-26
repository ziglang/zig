/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) Peter Wemm
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

#ifndef _MACHINE_PCPU_H_
#define	_MACHINE_PCPU_H_

#include <machine/segments.h>
#include <machine/tss.h>

#include <sys/_lock.h>
#include <sys/_mutex.h>

struct monitorbuf {
	int idle_state;		/* Used by cpu_idle_mwait. */
	int stop_state;		/* Used by cpustop_handler. */
	char padding[128 - (2 * sizeof(int))];
};
_Static_assert(sizeof(struct monitorbuf) == 128, "2x cache line");

/*
 * The SMP parts are setup in pmap.c and machdep.c for the BSP, and
 * pmap.c and mp_machdep.c sets up the data for the AP's to "see" when
 * they awake.  The reason for doing it via a struct is so that an
 * array of pointers to each CPU's data can be set up for things like
 * "check curproc on all other processors"
 */

#define	PCPU_MD_FIELDS							\
	struct monitorbuf pc_monitorbuf __aligned(128);	/* cache line */\
	struct	pcpu *pc_prvspace;	/* Self-reference */		\
	struct	pmap *pc_curpmap;					\
	struct	segment_descriptor pc_common_tssd;			\
	struct	segment_descriptor *pc_tss_gdt;				\
	struct	segment_descriptor *pc_fsgs_gdt;			\
	struct	i386tss *pc_common_tssp;				\
	u_int	pc_kesp0;						\
	u_int	pc_trampstk;						\
	int	pc_currentldt;						\
	u_int   pc_acpi_id;		/* ACPI CPU id */		\
	u_int	pc_apic_id;						\
	int	pc_private_tss;		/* Flag indicating private tss*/\
	u_int	pc_cmci_mask;		/* MCx banks for CMCI */	\
	u_int	pc_vcpu_id;		/* Xen vCPU ID */		\
	struct	mtx pc_cmap_lock;					\
	void	*pc_cmap_pte1;						\
	void	*pc_cmap_pte2;						\
	caddr_t	pc_cmap_addr1;						\
	caddr_t	pc_cmap_addr2;						\
	vm_offset_t pc_qmap_addr;	/* KVA for temporary mappings */\
	vm_offset_t pc_copyout_maddr;					\
	vm_offset_t pc_copyout_saddr;					\
	struct	mtx pc_copyout_mlock;					\
	struct	sx pc_copyout_slock;					\
	char	*pc_copyout_buf;					\
	vm_offset_t pc_pmap_eh_va;					\
	caddr_t pc_pmap_eh_ptep;					\
	uint32_t pc_smp_tlb_done;	/* TLB op acknowledgement */	\
	uint32_t pc_ibpb_set;						\
	void	*pc_mds_buf;						\
	void	*pc_mds_buf64;						\
	uint32_t pc_pad[4];						\
	uint8_t	pc_mds_tmp[64];						\
	u_int	pc_ipi_bitmap;						\
	char	__pad[3518]

#ifdef _KERNEL

#define MONITOR_STOPSTATE_RUNNING	0
#define MONITOR_STOPSTATE_STOPPED	1

/*
 * Evaluates to the byte offset of the per-cpu variable name.
 */
#define	__pcpu_offset(name)						\
	__offsetof(struct pcpu, name)

/*
 * Evaluates to the type of the per-cpu variable name.
 */
#define	__pcpu_type(name)						\
	__typeof(((struct pcpu *)0)->name)

/*
 * Evaluates to the address of the per-cpu variable name.
 */
#define	__PCPU_PTR(name) __extension__ ({				\
	__pcpu_type(name) *__p;						\
									\
	__asm __volatile("movl %%fs:%1,%0; addl %2,%0"			\
	    : "=r" (__p)						\
	    : "m" (*(struct pcpu *)(__pcpu_offset(pc_prvspace))),	\
	      "i" (__pcpu_offset(name)));				\
									\
	__p;								\
})

/*
 * Evaluates to the value of the per-cpu variable name.
 */
#define	__PCPU_GET(name) __extension__ ({				\
	__pcpu_type(name) __res;					\
	struct __s {							\
		u_char	__b[MIN(sizeof(__res), 4)];			\
	} __s;								\
									\
	if (sizeof(__res) == 1 || sizeof(__res) == 2 ||			\
	    sizeof(__res) == 4) {					\
		__asm __volatile("mov %%fs:%1,%0"			\
		    : "=r" (__s)					\
		    : "m" (*(struct __s *)(__pcpu_offset(name))));	\
		*(struct __s *)(void *)&__res = __s;			\
	} else {							\
		__res = *__PCPU_PTR(name);				\
	}								\
	__res;								\
})

/*
 * Adds a value of the per-cpu counter name.  The implementation
 * must be atomic with respect to interrupts.
 */
#define	__PCPU_ADD(name, val) do {					\
	__pcpu_type(name) __val;					\
	struct __s {							\
		u_char	__b[MIN(sizeof(__val), 4)];			\
	} __s;								\
									\
	__val = (val);							\
	if (sizeof(__val) == 1 || sizeof(__val) == 2 ||			\
	    sizeof(__val) == 4) {					\
		__s = *(struct __s *)(void *)&__val;			\
		__asm __volatile("add %1,%%fs:%0"			\
		    : "=m" (*(struct __s *)(__pcpu_offset(name)))	\
		    : "r" (__s));					\
	} else								\
		*__PCPU_PTR(name) += __val;				\
} while (0)

/*
 * Sets the value of the per-cpu variable name to value val.
 */
#define	__PCPU_SET(name, val) do {					\
	__pcpu_type(name) __val;					\
	struct __s {							\
		u_char	__b[MIN(sizeof(__val), 4)];			\
	} __s;								\
									\
	__val = (val);							\
	if (sizeof(__val) == 1 || sizeof(__val) == 2 ||			\
	    sizeof(__val) == 4) {					\
		__s = *(struct __s *)(void *)&__val;			\
		__asm __volatile("mov %1,%%fs:%0"			\
		    : "=m" (*(struct __s *)(__pcpu_offset(name)))	\
		    : "r" (__s));					\
	} else {							\
		*__PCPU_PTR(name) = __val;				\
	}								\
} while (0)

#define	get_pcpu() __extension__ ({					\
	struct pcpu *__pc;						\
									\
	__asm __volatile("movl %%fs:%1,%0"				\
	    : "=r" (__pc)						\
	    : "m" (*(struct pcpu *)(__pcpu_offset(pc_prvspace))));	\
	__pc;								\
})

#define	PCPU_GET(member)	__PCPU_GET(pc_ ## member)
#define	PCPU_ADD(member, val)	__PCPU_ADD(pc_ ## member, val)
#define	PCPU_PTR(member)	__PCPU_PTR(pc_ ## member)
#define	PCPU_SET(member, val)	__PCPU_SET(pc_ ## member, val)

#define	IS_BSP()	(PCPU_GET(cpuid) == 0)

#endif /* _KERNEL */

#endif /* !_MACHINE_PCPU_H_ */