/*
 * Copyright (c) 2013 Apple Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */

#ifndef _VM_PAGE_SIZE_H_
#define _VM_PAGE_SIZE_H_

#include <Availability.h>
#include <mach/mach_types.h>
#include <sys/cdefs.h>

__BEGIN_DECLS

/*
 *	Globally interesting numbers.
 *	These macros assume vm_page_size is a power-of-2.
 */
extern  vm_size_t       vm_page_size;
extern  vm_size_t       vm_page_mask;
extern  int             vm_page_shift;

/*
 *	These macros assume vm_page_size is a power-of-2.
 */
#define trunc_page(x)   ((x) & (~(vm_page_size - 1)))
#define round_page(x)   trunc_page((x) + (vm_page_size - 1))

/*
 *	Page-size rounding macros for the fixed-width VM types.
 */
#define mach_vm_trunc_page(x) ((mach_vm_offset_t)(x) & ~((signed)vm_page_mask))
#define mach_vm_round_page(x) (((mach_vm_offset_t)(x) + vm_page_mask) & ~((signed)vm_page_mask))


extern  vm_size_t       vm_kernel_page_size     __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);
extern  vm_size_t       vm_kernel_page_mask     __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);
extern  int             vm_kernel_page_shift    __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);

#define trunc_page_kernel(x)   ((x) & (~vm_kernel_page_mask))
#define round_page_kernel(x)   trunc_page_kernel((x) + vm_kernel_page_mask)

__END_DECLS

#endif