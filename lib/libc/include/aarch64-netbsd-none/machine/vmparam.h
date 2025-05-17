/* $NetBSD: vmparam.h,v 1.19.4.1 2024/07/03 19:13:20 martin Exp $ */

/*-
 * Copyright (c) 2014 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Matt Thomas of 3am Software Foundry.
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

#ifndef _AARCH64_VMPARAM_H_
#define _AARCH64_VMPARAM_H_

#ifdef __aarch64__

#define	__USE_TOPDOWN_VM

/*
 * Default pager_map of 16MB is small and we have plenty of VA to burn.
 */
#define	PAGER_MAP_DEFAULT_SIZE	(512 * 1024 * 1024)

/*
 * Defaults for Unified Buffer Cache parameters.
 */

#ifndef UBC_WINSHIFT
#define	UBC_WINSHIFT	16	/* 64kB */
#endif
#ifndef UBC_NWINS
#define	UBC_NWINS	4096	/* 256MB */
#endif

/*
 * AARCH64 supports 3 page sizes: 4KB, 16KB, 64KB.  Each page table can
 * even have its own page size.
 */

#ifdef AARCH64_PAGE_SHIFT
#if (1 << AARCH64_PAGE_SHIFT) & ~0x141000
#error AARCH64_PAGE_SHIFT contains an unsupported value.
#endif
#define PAGE_SHIFT	AARCH64_PAGE_SHIFT
#else
#define PAGE_SHIFT	12
#endif
#define PAGE_SIZE	(1 << PAGE_SHIFT)
#define PAGE_MASK	(PAGE_SIZE - 1)

#if PAGE_SHIFT <= 14
#define USPACE		32768
#else
#define USPACE		65536
#endif
#define	UPAGES		(USPACE >> PAGE_SHIFT)

/*
 * USRSTACK is the top (end) of the user stack.  The user VA space is a
 * 48-bit address space starting at 0.  Place the stack at its top end.
 */
#define USRSTACK	VM_MAXUSER_ADDRESS

#ifndef MAXTSIZ
#define	MAXTSIZ		(1L << 30)	/* max text size (1GB) */
#endif

#ifndef MAXDSIZ
#define	MAXDSIZ		(1L << 36)	/* max data size (64GB) */
#endif

#ifndef MAXSSIZ
#define	MAXSSIZ		(1L << 26)	/* max stack size (64MB) */
#endif

#ifndef DFLDSIZ
#define	DFLDSIZ		(1L << 32)	/* default data size (4GB) */
#endif

#ifndef DFLSSIZ
#define	DFLSSIZ		(1L << 23)	/* default stack size (8MB) */
#endif

#define USRSTACK32	VM_MAXUSER_ADDRESS32

#ifndef	MAXDSIZ32
#define	MAXDSIZ32	(3U*1024*1024*1024)	/* max data size */
#endif

#ifndef	MAXSSIZ32
#define	MAXSSIZ32	(64*1024*1024)		/* max stack size */
#endif

#ifndef DFLDSIZ32
#define	DFLDSIZ32	(1L << 27)	/* 32bit default data size (128MB) */
#endif

#ifndef DFLSSIZ32
#define	DFLSSIZ32	(1L << 21)	/* 32bit default stack size (2MB) */
#endif

#define	VM_MIN_ADDRESS		((vaddr_t) 0x0)
#define	VM_MAXUSER_ADDRESS	((vaddr_t) (1L << 48) - PAGE_SIZE)
#define	VM_MAX_ADDRESS		VM_MAXUSER_ADDRESS

#define VM_MAXUSER_ADDRESS32	((vaddr_t) 0xfffff000)

/*
 * kernel virtual space layout:
 *   0xffff_0000_0000_0000  -   64T  direct mapping
 *   0xffff_4000_0000_0000  -   32T  (KASAN SHADOW MAP)
 *   0xffff_6000_0000_0000  -   32T  (not used)
 *   0xffff_8000_0000_0000  -    1G  (EFI_RUNTIME - legacy)
 *   0xffff_8000_4000_0000  -   64T  (not used)
 *   0xffff_c000_0000_0000  -   64T  KERNEL VM Space (including text/data/bss)
 *  (0xffff_c000_4000_0000     -1GB) KERNEL VM start of KVM
 *   0xffff_ffff_f000_0000  -  254M  KERNEL_IO for pmap_devmap
 *   0xffff_ffff_ffe0_0000  -    2M  RESERVED
 */
#define VM_MIN_KERNEL_ADDRESS	((vaddr_t) 0xffffc00000000000L)
#define VM_MAX_KERNEL_ADDRESS	((vaddr_t) 0xffffffffffe00000L)

/*
 * Reserved space for EFI runtime services (legacy)
 */
#define	EFI_RUNTIME_VA		0xffff800000000000L
#define	EFI_RUNTIME_SIZE	0x0000000040000000L


/*
 * last 254MB of kernel vm area (0xfffffffff0000000-0xffffffffffe00000)
 * may be used for devmap.  see aarch64/pmap.c:pmap_devmap_*
 */
#define VM_KERNEL_IO_ADDRESS	0xfffffffff0000000L
#define VM_KERNEL_IO_SIZE	(VM_MAX_KERNEL_ADDRESS - VM_KERNEL_IO_ADDRESS)

#define VM_KERNEL_VM_BASE	(0xffffc00040000000L)
#define VM_KERNEL_VM_SIZE	(VM_KERNEL_IO_ADDRESS - VM_KERNEL_VM_BASE)

/* virtual sizes (bytes) for various kernel submaps */
#define USRIOSIZE		(PAGE_SIZE / 8)
#define VM_PHYS_SIZE		(USRIOSIZE * PAGE_SIZE)

#define VM_DEFAULT_ADDRESS32_TOPDOWN(da, sz) \
	trunc_page(USRSTACK32 - MAXSSIZ32 - (sz) - user_stack_guard_size)
#define VM_DEFAULT_ADDRESS32_BOTTOMUP(da, sz) \
	round_page((vaddr_t)(da) + (vsize_t)MAXDSIZ32)

/*
 * Since we have the address space, we map all of physical memory (RAM)
 * using block page table entries.
 */
#define AARCH64_DIRECTMAP_MASK	((vaddr_t) 0xffff000000000000L)
#define AARCH64_DIRECTMAP_SIZE	(1UL << 46)	/* 64TB */
#define AARCH64_DIRECTMAP_START	AARCH64_DIRECTMAP_MASK
#define AARCH64_DIRECTMAP_END	(AARCH64_DIRECTMAP_START + AARCH64_DIRECTMAP_SIZE)
#define AARCH64_KVA_P(va)	(((vaddr_t) (va) & AARCH64_DIRECTMAP_MASK) != 0)
#define AARCH64_PA_TO_KVA(pa)	((vaddr_t) ((pa) | AARCH64_DIRECTMAP_START))
#define AARCH64_KVA_TO_PA(va)	((paddr_t) ((va) & ~AARCH64_DIRECTMAP_MASK))

/* */
#define VM_PHYSSEG_MAX		256              /* XXX */
#define VM_PHYSSEG_STRAT	VM_PSTRAT_BSEARCH

#define VM_NFREELIST		1
#define VM_FREELIST_DEFAULT	0

#elif defined(__arm__)

#include <arm/vmparam.h>

#endif /* __aarch64__/__arm__ */

#endif /* _AARCH64_VMPARAM_H_ */