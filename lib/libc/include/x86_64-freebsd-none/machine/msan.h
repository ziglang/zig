/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2021 The FreeBSD Foundation
 *
 * This software was developed by Mark Johnston under sponsorship from the
 * FreeBSD Foundation.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the distribution.
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

#ifndef _MACHINE_MSAN_H_
#define	_MACHINE_MSAN_H_

#ifdef KMSAN

#include <vm/vm.h>
#include <vm/pmap.h>
#include <vm/vm_page.h>
#include <machine/vmparam.h>

typedef uint32_t msan_orig_t;

/*
 * Our 32-bit origin cells encode a 2-bit type and 30-bit pointer to a kernel
 * instruction.  The pointer is compressed by making it a positive offset
 * relative to KERNBASE.
 */
#define	KMSAN_ORIG_TYPE_SHIFT	30u
#define	KMSAN_ORIG_PTR_MASK	((1u << KMSAN_ORIG_TYPE_SHIFT) - 1)

static inline msan_orig_t
kmsan_md_orig_encode(int type, uintptr_t ptr)
{
	return ((type << KMSAN_ORIG_TYPE_SHIFT) |
	    ((ptr & KMSAN_ORIG_PTR_MASK)));
}

static inline void
kmsan_md_orig_decode(msan_orig_t orig, int *type, uintptr_t *ptr)
{
	*type = orig >> KMSAN_ORIG_TYPE_SHIFT;
	*ptr = (orig & KMSAN_ORIG_PTR_MASK) | KERNBASE;
}

static inline vm_offset_t
kmsan_md_addr_to_shad(vm_offset_t addr)
{
	return (addr - VM_MIN_KERNEL_ADDRESS + KMSAN_SHAD_MIN_ADDRESS);
}

static inline vm_offset_t
kmsan_md_addr_to_orig(vm_offset_t addr)
{
	return (addr - VM_MIN_KERNEL_ADDRESS + KMSAN_ORIG_MIN_ADDRESS);
}

static inline bool
kmsan_md_unsupported(vm_offset_t addr)
{
	/*
	 * The kernel itself isn't shadowed: for most purposes global variables
	 * are always initialized, and because KMSAN kernels are large
	 * (GENERIC-KMSAN is ~80MB at the time of writing), shadowing would
	 * incur signficant memory usage.
	 */
	return (addr < VM_MIN_KERNEL_ADDRESS || addr >= KERNBASE);
}

#endif /* KMSAN */

#endif /* !_MACHINE_MSAN_H_ */