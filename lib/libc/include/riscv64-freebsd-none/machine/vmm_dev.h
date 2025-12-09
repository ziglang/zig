/*
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2015 Mihai Carabas <mihai.carabas@gmail.com>
 * Copyright (c) 2024 Ruslan Bukin <br@bsdpad.com>
 *
 * This software was developed by the University of Cambridge Computer
 * Laboratory (Department of Computer Science and Technology) under Innovate
 * UK project 105694, "Digital Security by Design (DSbD) Technology Platform
 * Prototype".
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
 * THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef	_VMM_DEV_H_
#define	_VMM_DEV_H_

#include <sys/domainset.h>

#include <machine/vmm.h>

struct vm_memmap {
	vm_paddr_t	gpa;
	int		segid;		/* memory segment */
	vm_ooffset_t	segoff;		/* offset into memory segment */
	size_t		len;		/* mmap length */
	int		prot;		/* RWX */
	int		flags;
};
#define	VM_MEMMAP_F_WIRED	0x01

struct vm_munmap {
	vm_paddr_t	gpa;
	size_t		len;
};

#define	VM_MEMSEG_NAME(m)	((m)->name[0] != '\0' ? (m)->name : NULL)
struct vm_memseg {
	int		segid;
	size_t		len;
	char		name[VM_MAX_SUFFIXLEN + 1];
	domainset_t	*ds_mask;
	size_t		ds_mask_size;
	int		ds_policy;
};

struct vm_register {
	int		cpuid;
	int		regnum;		/* enum vm_reg_name */
	uint64_t	regval;
};

struct vm_register_set {
	int		cpuid;
	unsigned int	count;
	const int	*regnums;	/* enum vm_reg_name */
	uint64_t	*regvals;
};

struct vm_run {
	int		cpuid;
	cpuset_t	*cpuset;	/* CPU set storage */
	size_t		cpusetsize;
	struct vm_exit	*vm_exit;
};

struct vm_exception {
	int		cpuid;
	uint64_t	scause;
};

struct vm_msi {
	uint64_t	msg;
	uint64_t	addr;
	int		bus;
	int		slot;
	int		func;
};

struct vm_capability {
	int		cpuid;
	enum vm_cap_type captype;
	int		capval;
	int		allcpus;
};

#define	MAX_VM_STATS	64
struct vm_stats {
	int		cpuid;				/* in */
	int		index;				/* in */
	int		num_entries;			/* out */
	struct timeval	tv;
	uint64_t	statbuf[MAX_VM_STATS];
};
struct vm_stat_desc {
	int		index;				/* in */
	char		desc[128];			/* out */
};

struct vm_suspend {
	enum vm_suspend_how how;
};

struct vm_gla2gpa {
	int		vcpuid;		/* inputs */
	int 		prot;		/* PROT_READ or PROT_WRITE */
	uint64_t	gla;
	struct vm_guest_paging paging;
	int		fault;		/* outputs */
	uint64_t	gpa;
};

struct vm_activate_cpu {
	int		vcpuid;
};

struct vm_cpuset {
	int		which;
	int		cpusetsize;
	cpuset_t	*cpus;
};
#define	VM_ACTIVE_CPUS		0
#define	VM_SUSPENDED_CPUS	1
#define	VM_DEBUG_CPUS		2

struct vm_aplic_descr {
	uint64_t mem_start;
	uint64_t mem_size;
};

struct vm_irq {
	uint32_t irq;
};

struct vm_cpu_topology {
	uint16_t	sockets;
	uint16_t	cores;
	uint16_t	threads;
	uint16_t	maxcpus;
};

enum {
	/* general routines */
	IOCNUM_ABIVERS = 0,
	IOCNUM_RUN = 1,
	IOCNUM_SET_CAPABILITY = 2,
	IOCNUM_GET_CAPABILITY = 3,
	IOCNUM_SUSPEND = 4,
	IOCNUM_REINIT = 5,

	/* memory apis */
	IOCNUM_GET_GPA_PMAP = 12,
	IOCNUM_GLA2GPA_NOFAULT = 13,
	IOCNUM_ALLOC_MEMSEG = 14,
	IOCNUM_GET_MEMSEG = 15,
	IOCNUM_MMAP_MEMSEG = 16,
	IOCNUM_MMAP_GETNEXT = 17,
	IOCNUM_MUNMAP_MEMSEG = 18,

	/* register/state accessors */
	IOCNUM_SET_REGISTER = 20,
	IOCNUM_GET_REGISTER = 21,
	IOCNUM_SET_REGISTER_SET = 24,
	IOCNUM_GET_REGISTER_SET = 25,

	/* statistics */
	IOCNUM_VM_STATS = 50,
	IOCNUM_VM_STAT_DESC = 51,

	/* CPU Topology */
	IOCNUM_SET_TOPOLOGY = 63,
	IOCNUM_GET_TOPOLOGY = 64,

	/* interrupt injection */
	IOCNUM_ASSERT_IRQ = 80,
	IOCNUM_DEASSERT_IRQ = 81,
	IOCNUM_RAISE_MSI = 82,
	IOCNUM_INJECT_EXCEPTION = 83,

	/* vm_cpuset */
	IOCNUM_ACTIVATE_CPU = 90,
	IOCNUM_GET_CPUSET = 91,
	IOCNUM_SUSPEND_CPU = 92,
	IOCNUM_RESUME_CPU = 93,

	/* vm_attach_aplic */
	IOCNUM_ATTACH_APLIC = 110,
};

#define	VM_RUN		\
	_IOWR('v', IOCNUM_RUN, struct vm_run)
#define	VM_SUSPEND	\
	_IOW('v', IOCNUM_SUSPEND, struct vm_suspend)
#define	VM_REINIT	\
	_IO('v', IOCNUM_REINIT)
#define	VM_ALLOC_MEMSEG	\
	_IOW('v', IOCNUM_ALLOC_MEMSEG, struct vm_memseg)
#define	VM_GET_MEMSEG	\
	_IOWR('v', IOCNUM_GET_MEMSEG, struct vm_memseg)
#define	VM_MMAP_MEMSEG	\
	_IOW('v', IOCNUM_MMAP_MEMSEG, struct vm_memmap)
#define	VM_MMAP_GETNEXT	\
	_IOWR('v', IOCNUM_MMAP_GETNEXT, struct vm_memmap)
#define	VM_MUNMAP_MEMSEG	\
	_IOW('v', IOCNUM_MUNMAP_MEMSEG, struct vm_munmap)
#define	VM_SET_REGISTER \
	_IOW('v', IOCNUM_SET_REGISTER, struct vm_register)
#define	VM_GET_REGISTER \
	_IOWR('v', IOCNUM_GET_REGISTER, struct vm_register)
#define	VM_SET_REGISTER_SET \
	_IOW('v', IOCNUM_SET_REGISTER_SET, struct vm_register_set)
#define	VM_GET_REGISTER_SET \
	_IOWR('v', IOCNUM_GET_REGISTER_SET, struct vm_register_set)
#define	VM_SET_CAPABILITY \
	_IOW('v', IOCNUM_SET_CAPABILITY, struct vm_capability)
#define	VM_GET_CAPABILITY \
	_IOWR('v', IOCNUM_GET_CAPABILITY, struct vm_capability)
#define	VM_STATS \
	_IOWR('v', IOCNUM_VM_STATS, struct vm_stats)
#define	VM_STAT_DESC \
	_IOWR('v', IOCNUM_VM_STAT_DESC, struct vm_stat_desc)
#define VM_ASSERT_IRQ \
	_IOW('v', IOCNUM_ASSERT_IRQ, struct vm_irq)
#define VM_DEASSERT_IRQ \
	_IOW('v', IOCNUM_DEASSERT_IRQ, struct vm_irq)
#define VM_RAISE_MSI \
	_IOW('v', IOCNUM_RAISE_MSI, struct vm_msi)
#define	VM_INJECT_EXCEPTION	\
	_IOW('v', IOCNUM_INJECT_EXCEPTION, struct vm_exception)
#define VM_SET_TOPOLOGY \
	_IOW('v', IOCNUM_SET_TOPOLOGY, struct vm_cpu_topology)
#define VM_GET_TOPOLOGY \
	_IOR('v', IOCNUM_GET_TOPOLOGY, struct vm_cpu_topology)
#define	VM_GLA2GPA_NOFAULT \
	_IOWR('v', IOCNUM_GLA2GPA_NOFAULT, struct vm_gla2gpa)
#define	VM_ACTIVATE_CPU	\
	_IOW('v', IOCNUM_ACTIVATE_CPU, struct vm_activate_cpu)
#define	VM_GET_CPUS	\
	_IOW('v', IOCNUM_GET_CPUSET, struct vm_cpuset)
#define	VM_SUSPEND_CPU \
	_IOW('v', IOCNUM_SUSPEND_CPU, struct vm_activate_cpu)
#define	VM_RESUME_CPU \
	_IOW('v', IOCNUM_RESUME_CPU, struct vm_activate_cpu)
#define	VM_ATTACH_APLIC	\
	_IOW('v', IOCNUM_ATTACH_APLIC, struct vm_aplic_descr)
#endif