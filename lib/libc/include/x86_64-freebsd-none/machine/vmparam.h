/*-
 * SPDX-License-Identifier: BSD-4-Clause
 *
 * Copyright (c) 1990 The Regents of the University of California.
 * All rights reserved.
 * Copyright (c) 1994 John S. Dyson
 * All rights reserved.
 * Copyright (c) 2003 Peter Wemm
 * All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * William Jolitz.
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
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	from: @(#)vmparam.h	5.9 (Berkeley) 5/12/91
 */

#ifdef __i386__
#include <i386/vmparam.h>
#else /* !__i386__ */

#ifndef _MACHINE_VMPARAM_H_
#define	_MACHINE_VMPARAM_H_ 1

/*
 * Machine dependent constants for AMD64.
 */

/*
 * Virtual memory related constants, all in bytes
 */
#define	MAXTSIZ		(32768UL*1024*1024)	/* max text size */
#ifndef DFLDSIZ
#define	DFLDSIZ		(32768UL*1024*1024)	/* initial data size limit */
#endif
#ifndef MAXDSIZ
#define	MAXDSIZ		(32768UL*1024*1024)	/* max data size */
#endif
#ifndef	DFLSSIZ
#define	DFLSSIZ		(8UL*1024*1024)		/* initial stack size limit */
#endif
#ifndef	MAXSSIZ
#define	MAXSSIZ		(512UL*1024*1024)	/* max stack size */
#endif
#ifndef SGROWSIZ
#define	SGROWSIZ	(128UL*1024)		/* amount to grow stack */
#endif

/*
 * We provide a machine specific single page allocator through the use
 * of the direct mapped segment.  This uses 2MB pages for reduced
 * TLB pressure.
 */
#if !defined(KASAN) && !defined(KMSAN)
#define	UMA_MD_SMALL_ALLOC
#endif

/*
 * The physical address space is densely populated.
 */
#define	VM_PHYSSEG_DENSE

/*
 * The number of PHYSSEG entries must be one greater than the number
 * of phys_avail entries because the phys_avail entry that spans the
 * largest physical address that is accessible by ISA DMA is split
 * into two PHYSSEG entries. 
 */
#define	VM_PHYSSEG_MAX		63

/*
 * Create two free page pools: VM_FREEPOOL_DEFAULT is the default pool
 * from which physical pages are allocated and VM_FREEPOOL_DIRECT is
 * the pool from which physical pages for page tables and small UMA
 * objects are allocated.
 */
#define	VM_NFREEPOOL		2
#define	VM_FREEPOOL_DEFAULT	0
#define	VM_FREEPOOL_DIRECT	1

/*
 * Create up to three free page lists: VM_FREELIST_DMA32 is for physical pages
 * that have physical addresses below 4G but are not accessible by ISA DMA,
 * and VM_FREELIST_ISADMA is for physical pages that are accessible by ISA
 * DMA.
 */
#define	VM_NFREELIST		3
#define	VM_FREELIST_DEFAULT	0
#define	VM_FREELIST_DMA32	1
#define	VM_FREELIST_LOWMEM	2

#define VM_LOWMEM_BOUNDARY	(16 << 20)	/* 16MB ISA DMA limit */

/*
 * Create the DMA32 free list only if the number of physical pages above
 * physical address 4G is at least 16M, which amounts to 64GB of physical
 * memory.
 */
#define	VM_DMA32_NPAGES_THRESHOLD	16777216

/*
 * An allocation size of 16MB is supported in order to optimize the
 * use of the direct map by UMA.  Specifically, a cache line contains
 * at most 8 PDEs, collectively mapping 16MB of physical memory.  By
 * reducing the number of distinct 16MB "pages" that are used by UMA,
 * the physical memory allocator reduces the likelihood of both 2MB
 * page TLB misses and cache misses caused by 2MB page TLB misses.
 */
#define	VM_NFREEORDER		13

/*
 * Enable superpage reservations: 1 level.
 */
#ifndef	VM_NRESERVLEVEL
#define	VM_NRESERVLEVEL		1
#endif

/*
 * Level 0 reservations consist of 512 pages.
 */
#ifndef	VM_LEVEL_0_ORDER
#define	VM_LEVEL_0_ORDER	9
#endif

#ifdef	SMP
#define	PA_LOCK_COUNT	256
#endif

/*
 * Kernel physical load address for non-UEFI boot and for legacy UEFI loader.
 * Newer UEFI loader loads kernel anywhere below 4G, with memory allocated
 * by boot services.
 * Needs to be aligned at 2MB superpage boundary.
 */
#ifndef KERNLOAD
#define	KERNLOAD	0x200000
#endif

/*
 * Virtual addresses of things.  Derived from the page directory and
 * page table indexes from pmap.h for precision.
 *
 * 0x0000000000000000 - 0x00007fffffffffff   user map
 * 0x0000800000000000 - 0xffff7fffffffffff   does not exist (hole)
 * 0xffff800000000000 - 0xffff804020100fff   recursive page table (512GB slot)
 * 0xffff804020100fff - 0xffff807fffffffff   unused
 * 0xffff808000000000 - 0xffff847fffffffff   large map (can be tuned up)
 * 0xffff848000000000 - 0xfffff77fffffffff   unused (large map extends there)
 * 0xfffff60000000000 - 0xfffff7ffffffffff   2TB KMSAN origin map, optional
 * 0xfffff78000000000 - 0xfffff7bfffffffff   512GB KASAN shadow map, optional
 * 0xfffff80000000000 - 0xfffffbffffffffff   4TB direct map
 * 0xfffffc0000000000 - 0xfffffdffffffffff   2TB KMSAN shadow map, optional
 * 0xfffffe0000000000 - 0xffffffffffffffff   2TB kernel map
 *
 * Within the kernel map:
 *
 * 0xfffffe0000000000                        vm_page_array
 * 0xffffffff80000000                        KERNBASE
 */

#define	VM_MIN_KERNEL_ADDRESS	KV4ADDR(KPML4BASE, 0, 0, 0)
#define	VM_MAX_KERNEL_ADDRESS	KV4ADDR(KPML4BASE + NKPML4E - 1, \
					NPDPEPG-1, NPDEPG-1, NPTEPG-1)

#define	DMAP_MIN_ADDRESS	KV4ADDR(DMPML4I, 0, 0, 0)
#define	DMAP_MAX_ADDRESS	KV4ADDR(DMPML4I + NDMPML4E, 0, 0, 0)

#define	KASAN_MIN_ADDRESS	KV4ADDR(KASANPML4I, 0, 0, 0)
#define	KASAN_MAX_ADDRESS	KV4ADDR(KASANPML4I + NKASANPML4E, 0, 0, 0)

#define	KMSAN_SHAD_MIN_ADDRESS	KV4ADDR(KMSANSHADPML4I, 0, 0, 0)
#define	KMSAN_SHAD_MAX_ADDRESS	KV4ADDR(KMSANSHADPML4I + NKMSANSHADPML4E, \
					0, 0, 0)

#define	KMSAN_ORIG_MIN_ADDRESS	KV4ADDR(KMSANORIGPML4I, 0, 0, 0)
#define	KMSAN_ORIG_MAX_ADDRESS	KV4ADDR(KMSANORIGPML4I + NKMSANORIGPML4E, \
					0, 0, 0)

#define	LARGEMAP_MIN_ADDRESS	KV4ADDR(LMSPML4I, 0, 0, 0)
#define	LARGEMAP_MAX_ADDRESS	KV4ADDR(LMEPML4I + 1, 0, 0, 0)

/*
 * Formally kernel mapping starts at KERNBASE, but kernel linker
 * script leaves first PDE reserved.  For legacy BIOS boot, kernel is
 * loaded at KERNLOAD = 2M, and initial kernel page table maps
 * physical memory from zero to KERNend starting at KERNBASE.
 *
 * KERNSTART is where the first actual kernel page is mapped, after
 * the compatibility mapping.
 */
#define	KERNBASE		KV4ADDR(KPML4I, KPDPI, 0, 0)
#define	KERNSTART		(KERNBASE + NBPDR)

#define	UPT_MAX_ADDRESS		KV4ADDR(PML4PML4I, PML4PML4I, PML4PML4I, PML4PML4I)
#define	UPT_MIN_ADDRESS		KV4ADDR(PML4PML4I, 0, 0, 0)

#define	VM_MAXUSER_ADDRESS_LA57	UVADDR(NUPML5E, 0, 0, 0, 0)
#define	VM_MAXUSER_ADDRESS_LA48	UVADDR(0, NUP4ML4E, 0, 0, 0)
#define	VM_MAXUSER_ADDRESS	VM_MAXUSER_ADDRESS_LA57

#define	SHAREDPAGE_LA57		(VM_MAXUSER_ADDRESS_LA57 - PAGE_SIZE)
#define	SHAREDPAGE_LA48		(VM_MAXUSER_ADDRESS_LA48 - PAGE_SIZE)
#define	USRSTACK_LA57		SHAREDPAGE_LA57
#define	USRSTACK_LA48		SHAREDPAGE_LA48
#define	USRSTACK		USRSTACK_LA48
#define	PS_STRINGS_LA57		(USRSTACK_LA57 - sizeof(struct ps_strings))
#define	PS_STRINGS_LA48		(USRSTACK_LA48 - sizeof(struct ps_strings))

#define	VM_MAX_ADDRESS		UPT_MAX_ADDRESS
#define	VM_MIN_ADDRESS		(0)

/*
 * XXX Allowing dmaplimit == 0 is a temporary workaround for vt(4) efifb's
 * early use of PHYS_TO_DMAP before the mapping is actually setup. This works
 * because the result is not actually accessed until later, but the early
 * vt fb startup needs to be reworked.
 */
#define	PHYS_IN_DMAP(pa)	(dmaplimit == 0 || (pa) < dmaplimit)
#define	VIRT_IN_DMAP(va)	((va) >= DMAP_MIN_ADDRESS &&		\
    (va) < (DMAP_MIN_ADDRESS + dmaplimit))

#define	PMAP_HAS_DMAP	1
#define	PHYS_TO_DMAP(x)	({						\
	KASSERT(PHYS_IN_DMAP(x),					\
	    ("physical address %#jx not covered by the DMAP",		\
	    (uintmax_t)x));						\
	(x) | DMAP_MIN_ADDRESS; })

#define	DMAP_TO_PHYS(x)	({						\
	KASSERT(VIRT_IN_DMAP(x),					\
	    ("virtual address %#jx not covered by the DMAP",		\
	    (uintmax_t)x));						\
	(x) & ~DMAP_MIN_ADDRESS; })

/*
 * amd64 maps the page array into KVA so that it can be more easily
 * allocated on the correct memory domains.
 */
#define	PMAP_HAS_PAGE_ARRAY	1

/*
 * How many physical pages per kmem arena virtual page.
 */
#ifndef VM_KMEM_SIZE_SCALE
#define	VM_KMEM_SIZE_SCALE	(1)
#endif

/*
 * Optional ceiling (in bytes) on the size of the kmem arena: 60% of the
 * kernel map.
 */
#ifndef VM_KMEM_SIZE_MAX
#define	VM_KMEM_SIZE_MAX	((VM_MAX_KERNEL_ADDRESS - \
    VM_MIN_KERNEL_ADDRESS + 1) * 3 / 5)
#endif

/* initial pagein size of beginning of executable file */
#ifndef VM_INITIAL_PAGEIN
#define	VM_INITIAL_PAGEIN	16
#endif

#define	ZERO_REGION_SIZE	(2 * 1024 * 1024)	/* 2MB */

/*
 * The pmap can create non-transparent large page mappings.
 */
#define	PMAP_HAS_LARGEPAGES	1

/*
 * Need a page dump array for minidump.
 */
#define MINIDUMP_PAGE_TRACKING	1

#endif /* _MACHINE_VMPARAM_H_ */

#endif /* __i386__ */