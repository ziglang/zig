/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2020 The FreeBSD Foundation
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

#ifndef _MACHINE_ASAN_H_
#define	_MACHINE_ASAN_H_

#ifdef KASAN

#include <vm/vm.h>
#include <vm/pmap.h>
#include <vm/vm_page.h>
#include <machine/vmparam.h>

static inline vm_offset_t
kasan_md_addr_to_shad(vm_offset_t addr)
{
	return (((addr - VM_MIN_KERNEL_ADDRESS) >> KASAN_SHADOW_SCALE_SHIFT) +
	    KASAN_MIN_ADDRESS);
}

static inline bool
kasan_md_unsupported(vm_offset_t addr)
{
	vm_offset_t kernmin;

	/*
	 * The vm_page array is mapped at the beginning of the kernel map, but
	 * accesses to the array are not validated for now.  Handle the fact
	 * that KASAN must validate accesses before the vm_page array is
	 * initialized.
	 */
	kernmin = vm_page_array == NULL ? VM_MIN_KERNEL_ADDRESS :
	    (vm_offset_t)(vm_page_array + vm_page_array_size);
	return (addr < kernmin || addr >= VM_MAX_KERNEL_ADDRESS);
}

static inline void
kasan_md_init(void)
{
}

static inline void
kasan_md_init_early(vm_offset_t bootstack, size_t size)
{
	kasan_shadow_map(bootstack, size);
}

#endif /* KASAN */

#endif /* !_MACHINE_ASAN_H_ */