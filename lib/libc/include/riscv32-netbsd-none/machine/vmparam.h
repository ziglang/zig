/*	$NetBSD: vmparam.h,v 1.13 2022/10/16 06:14:53 skrll Exp $	*/

/*-
 * Copyright (c) 2014, 2020 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Matt Thomas of 3am Software Foundry, and Nick Hudson.
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
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _RISCV_VMPARAM_H_
#define	_RISCV_VMPARAM_H_

#include <riscv/param.h>

#ifdef _KERNEL_OPT
#include "opt_multiprocessor.h"
#endif

/*
 * Machine dependent VM constants for RISCV.
 */

/*
 * We use a 4K page on both RV64 and RV32 systems.
 * Override PAGE_* definitions to compile-time constants.
 */
#define	PAGE_SHIFT	PGSHIFT
#define	PAGE_SIZE	(1 << PAGE_SHIFT)
#define	PAGE_MASK	(PAGE_SIZE - 1)

/*
 * USRSTACK is the top (end) of the user stack.
 *
 * USRSTACK needs to start a page below the maxuser address so that a memory
 * access with a maximum displacement (0x7ff) won't cross into the kernel's
 * address space.  We use PAGE_SIZE instead of 0x800 since these need to be
 * page-aligned.
 */
#define	USRSTACK	(VM_MAXUSER_ADDRESS-PAGE_SIZE) /* Start of user stack */
#define	USRSTACK32	((uint32_t)VM_MAXUSER_ADDRESS32-PAGE_SIZE)

/*
 * Virtual memory related constants, all in bytes
 */
#ifndef MAXTSIZ
#define	MAXTSIZ		(128*1024*1024)		/* max text size */
#endif
#ifndef DFLDSIZ
#define	DFLDSIZ		(256*1024*1024)		/* initial data size limit */
#endif
#ifndef MAXDSIZ
#define	MAXDSIZ		(1536*1024*1024)	/* max data size */
#endif
#ifndef	DFLSSIZ
#define	DFLSSIZ		(4*1024*1024)		/* initial stack size limit */
#endif
#ifndef	MAXSSIZ
#define	MAXSSIZ		(120*1024*1024)		/* max stack size */
#endif

/*
 * Virtual memory related constants, all in bytes
 */
#ifndef DFLDSIZ32
#define	DFLDSIZ32	DFLDSIZ			/* initial data size limit */
#endif
#ifndef MAXDSIZ32
#define	MAXDSIZ32	MAXDSIZ			/* max data size */
#endif
#ifndef	DFLSSIZ32
#define	DFLSSIZ32	DFLTSIZ			/* initial stack size limit */
#endif
#ifndef	MAXSSIZ32
#define	MAXSSIZ32	MAXSSIZ			/* max stack size */
#endif

/*
 * PTEs for mapping user space into the kernel for phyio operations.
 * The default PTE number is enough to cover 8 disks * MAXBSIZE.
 */
#ifndef USRIOSIZE
#define USRIOSIZE	(MAXBSIZE/PAGE_SIZE * 8)
#endif

/*
 * User/kernel map constants.
 */
#define VM_MIN_ADDRESS		((vaddr_t)0x00000000)
#ifdef _LP64	/* Sv39 / Sv48 / Sv57 */
/*
 * kernel virtual space layout:
 *   0xffff_ffc0_0000_0000  -   64GiB  KERNEL VM Space (inc. text/data/bss)
 *  (0xffff_ffc0_4000_0000      +1GiB) KERNEL VM start of KVA
 *  (0xffff_ffd0_0000_0000      64GiB) reserved
 *   0xffff_ffe0_0000_0000  -  128GiB  direct mapping
 */
#define VM_MAXUSER_ADDRESS	((vaddr_t)0x0000004000000000 - 16 * PAGE_SIZE)
#define VM_MIN_KERNEL_ADDRESS	((vaddr_t)0xffffffc000000000)
#define VM_MAX_KERNEL_ADDRESS	((vaddr_t)0xffffffd000000000)

#else		/* Sv32 */
#define VM_MAXUSER_ADDRESS	((vaddr_t)-0x7fffffff-1)/* 0xffffffff80000000 */
#define VM_MIN_KERNEL_ADDRESS	((vaddr_t)-0x7fffffff-1)/* 0xffffffff80000000 */
#define VM_MAX_KERNEL_ADDRESS	((vaddr_t)-0x40000000)	/* 0xffffffffc0000000 */

#endif
#define VM_KERNEL_BASE		VM_MIN_KERNEL_ADDRESS
#define VM_KERNEL_SIZE		0x2000000	/* 32 MiB (8 / 16 megapages) */
#define VM_KERNEL_DTB_BASE	(VM_KERNEL_BASE + VM_KERNEL_SIZE)
#define VM_KERNEL_DTB_SIZE	0x1000000	/* 16 MiB (4 / 8 megapages) */
#define VM_KERNEL_IO_BASE	(VM_KERNEL_DTB_BASE + VM_KERNEL_DTB_SIZE)
#define VM_KERNEL_IO_SIZE	0x1000000	/* 16 MiB (4 / 8 megapages) */

#define VM_KERNEL_RESERVED	(VM_KERNEL_SIZE + VM_KERNEL_DTB_SIZE + VM_KERNEL_IO_SIZE)

#define VM_KERNEL_VM_BASE	(VM_MIN_KERNEL_ADDRESS + VM_KERNEL_RESERVED)
#define VM_KERNEL_VM_SIZE	(VM_MAX_KERNEL_ADDRESS - VM_KERNEL_VM_BASE)

#define VM_MAX_ADDRESS		VM_MAXUSER_ADDRESS
#define VM_MAXUSER_ADDRESS32	((vaddr_t)(1UL << 31))/* 0x0000000080000000 */

#ifdef _LP64
/*
 * Since we have the address space, we map all of physical memory (RAM)
 * using gigapages on SV39, terapages on SV48 and petapages on SV57.
 */
#define RISCV_DIRECTMAP_MASK	((vaddr_t) 0xffffffe000000000L)
#define RISCV_DIRECTMAP_SIZE	(-RISCV_DIRECTMAP_MASK - PAGE_SIZE)	/* 128GiB */
#define RISCV_DIRECTMAP_START	RISCV_DIRECTMAP_MASK
#define RISCV_DIRECTMAP_END	(RISCV_DIRECTMAP_START + RISCV_DIRECTMAP_SIZE)
#define RISCV_KVA_P(va)	(((vaddr_t) (va) & RISCV_DIRECTMAP_MASK) != 0)
#define RISCV_PA_TO_KVA(pa)	((vaddr_t) ((pa) | RISCV_DIRECTMAP_START))
#define RISCV_KVA_TO_PA(va)	((paddr_t) ((va) & ~RISCV_DIRECTMAP_MASK))
#endif

/*
 * The address to which unspecified mapping requests default
 */
#define __USE_TOPDOWN_VM

#define VM_DEFAULT_ADDRESS_TOPDOWN(da, sz) \
    trunc_page(USRSTACK - MAXSSIZ - (sz) - user_stack_guard_size)
#define VM_DEFAULT_ADDRESS_BOTTOMUP(da, sz) \
    round_page((vaddr_t)(da) + (vsize_t)maxdmap)

#define VM_DEFAULT_ADDRESS32_TOPDOWN(da, sz) \
    trunc_page(USRSTACK32 - MAXSSIZ32 - (sz) - user_stack_guard_size)
#define VM_DEFAULT_ADDRESS32_BOTTOMUP(da, sz) \
    round_page((vaddr_t)(da) + (vsize_t)MAXDSIZ32)

/* virtual sizes (bytes) for various kernel submaps */
#define VM_PHYS_SIZE		(USRIOSIZE*PAGE_SIZE)

/* VM_PHYSSEG_MAX defined by platform-dependent code. */
#ifndef VM_PHYSSEG_MAX
#define VM_PHYSSEG_MAX		16
#endif
#if VM_PHYSSEG_MAX == 1
#define	VM_PHYSSEG_STRAT	VM_PSTRAT_BIGFIRST
#else
#define	VM_PHYSSEG_STRAT	VM_PSTRAT_BSEARCH
#endif
#define	VM_PHYSSEG_NOADD	/* can add RAM after vm_mem_init */

#ifndef VM_NFREELIST
#define	VM_NFREELIST		2	/* 2 distinct memory segments */
#define VM_FREELIST_DEFAULT	0
#define VM_FREELIST_DIRECTMAP	1
#endif

#ifdef _KERNEL
#define	UVM_KM_VMFREELIST	riscv_poolpage_vmfreelist
extern int riscv_poolpage_vmfreelist;

#ifdef _LP64
void *	cpu_uarea_alloc(bool);
bool	cpu_uarea_free(void *);
#endif
#endif

#endif /* ! _RISCV_VMPARAM_H_ */