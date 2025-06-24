/*	$NetBSD: vmparam.h,v 1.56 2020/10/08 12:49:06 he Exp $	*/

/*
 * Copyright (c) 2001, 2002 Wasabi Systems, Inc.
 * All rights reserved.
 *
 * Written by Jason R. Thorpe for Wasabi Systems, Inc.
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
 *	This product includes software developed for the NetBSD Project by
 *	Wasabi Systems, Inc.
 * 4. The name of Wasabi Systems, Inc. may not be used to endorse
 *    or promote products derived from this software without specific prior
 *    written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY WASABI SYSTEMS, INC. ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL WASABI SYSTEMS, INC
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _ARM_ARM32_VMPARAM_H_
#define	_ARM_ARM32_VMPARAM_H_

#if defined(_KERNEL_OPT)
#include "opt_kasan.h"
#endif

/*
 * Virtual Memory parameters common to all arm32 platforms.
 */

#include <sys/cdefs.h>
#include <arm/cpuconf.h>
#include <arm/arm32/param.h>

#define	__USE_TOPDOWN_VM
#define	USRSTACK	VM_MAXUSER_ADDRESS

/*
 * ARMv4 systems are normaly configured for 256MB KVA only, so restrict
 * the size of the pager map to 4MB.
 */
#ifndef _ARM_ARCH_5
#define PAGER_MAP_DEFAULT_SIZE          (4 * 1024 * 1024)
#endif

/*
 * Note that MAXTSIZ can't be larger than 32M, otherwise the compiler
 * would have to be changed to not generate "bl" instructions.
 */
#define	MAXTSIZ		(128*1024*1024)		/* max text size */
#ifndef	DFLDSIZ
#define	DFLDSIZ		(384*1024*1024)		/* initial data size limit */
#endif
#ifndef	MAXDSIZ
#define	MAXDSIZ		(1856*1024*1024)	/* max data size */
#endif
#ifndef	DFLSSIZ
#define	DFLSSIZ		(4*1024*1024)		/* initial stack size limit */
#endif
#ifndef	MAXSSIZ
#define	MAXSSIZ		(64*1024*1024)		/* max stack size */
#endif

/*
 * While the ARM architecture defines Section mappings, large pages,
 * and small pages, the standard MMU page size is (and will always be) 4K.
 */
#define	PAGE_SHIFT	PGSHIFT
#define	PAGE_SIZE	(1 << PAGE_SHIFT)
#define	PAGE_MASK	(PAGE_SIZE - 1)

/*
 * Mach derived constants
 */
#define	VM_MIN_ADDRESS		((vaddr_t) PAGE_SIZE)

#define	VM_MAXUSER_ADDRESS	((vaddr_t) KERNEL_BASE - PAGE_SIZE)
#define	VM_MAX_ADDRESS		VM_MAXUSER_ADDRESS

#define	VM_MIN_KERNEL_ADDRESS	((vaddr_t) KERNEL_BASE)
#define	VM_MAX_KERNEL_ADDRESS	((vaddr_t) -(PAGE_SIZE+1))

#if defined(_KERNEL)
// AddressSanitizer dedicates 1/8 of kernel memory to its shadow memory (e.g.
// 128MB to cover 1GB for ARM) and uses a special KVA range for the shadow
// address corresponding to a kernel memory address.

/*
 * kernel virtual space layout without direct map (common case)
 *
 *   0x8000_0000 -  256MB kernel text/data/bss
 *   0x9000_0000 - 1536MB Kernel VM Space
 *   0xf000_0000 -  256MB IO
 *
 * kernel virtual space layout with KASAN
 *
 *   0x8000_0000 -  256MB kernel text/data/bss
 *   0x9000_0000 -  768MB Kernel VM Space
 *   0xc000_0000 -  128MB (KASAN SHADOW MAP)
 *   0xc800_0000 -  640MB (spare)
 *   0xf000_0000 -  256MB IO
 *
 * kernel virtual space layout with direct map (1GB limited)
 *   0x8000_0000 - 1024MB kernel text/data/bss and direct map start
 *   0xc000_0000 -  768MB Kernel VM Space
 *   0xf000_0000 -  256MB IO
 *
 */

#ifdef KASAN
#define VM_KERNEL_KASAN_BASE	0xc0000000
#define VM_KERNEL_KASAN_SIZE	(VM_KERNEL_ADDR_SIZE >> KASAN_SHADOW_SCALE_SHIFT)
#define VM_KERNEL_KASAN_END	(VM_KERNEL_KASAN_BASE + VM_KERNEL_KASAN_SIZE)
#define VM_KERNEL_VM_END	VM_KERNEL_KASAN_BASE
#else
#define VM_KERNEL_VM_END	VM_KERNEL_IO_ADDRESS
#endif

#ifdef __HAVE_MM_MD_DIRECT_MAPPED_PHYS
#ifdef KASAN
#error KASAN and __HAVE_MM_MD_DIRECT_MAPPED_PHYS is unsupported
#endif
#define VM_KERNEL_VM_BASE	0xc0000000
#else
#define VM_KERNEL_VM_BASE	0x90000000
#endif

#define VM_KERNEL_ADDR_SIZE	(VM_KERNEL_VM_END - KERNEL_BASE)
#define VM_KERNEL_VM_SIZE	(VM_KERNEL_VM_END - VM_KERNEL_VM_BASE)

#define VM_KERNEL_IO_ADDRESS	0xf0000000
#define VM_KERNEL_IO_SIZE	(VM_MAX_KERNEL_ADDRESS - VM_KERNEL_IO_ADDRESS)
#endif

#endif /* _ARM_ARM32_VMPARAM_H_ */