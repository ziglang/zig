/*
 * Copyright (c) 2000-2018 Apple Inc. All rights reserved.
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
/*
 * @OSF_COPYRIGHT@
 *
 */
#ifndef _MACH_VM_TYPES_H_
#define _MACH_VM_TYPES_H_

#include <mach/port.h>
#include <mach/machine/vm_types.h>

#include <stdint.h>

typedef vm_offset_t             pointer_t;
typedef vm_offset_t             vm_address_t;

/*
 * We use addr64_t for 64-bit addresses that are used on both
 * 32 and 64-bit machines.  On PPC, they are passed and returned as
 * two adjacent 32-bit GPRs.  We use addr64_t in places where
 * common code must be useable both on 32 and 64-bit machines.
 */
typedef uint64_t addr64_t;              /* Basic effective address */

/*
 * We use reg64_t for addresses that are 32 bits on a 32-bit
 * machine, and 64 bits on a 64-bit machine, but are always
 * passed and returned in a single GPR on PPC.  This type
 * cannot be used in generic 32-bit c, since on a 64-bit
 * machine the upper half of the register will be ignored
 * by the c compiler in 32-bit mode.  In c, we can only use the
 * type in prototypes of functions that are written in and called
 * from assembly language.  This type is basically a comment.
 */
typedef uint32_t        reg64_t;

/*
 * To minimize the use of 64-bit fields, we keep some physical
 * addresses (that are page aligned) as 32-bit page numbers.
 * This limits the physical address space to 16TB of RAM.
 */
typedef uint32_t ppnum_t;               /* Physical page number */
#define PPNUM_MAX UINT32_MAX



typedef mach_port_t             vm_map_t, vm_map_read_t, vm_map_inspect_t;


#define VM_MAP_NULL             ((vm_map_t) 0)
#define VM_MAP_INSPECT_NULL     ((vm_map_inspect_t) 0)
#define VM_MAP_READ_NULL        ((vm_map_read_t) 0)

/*
 * Evolving definitions, likely to change.
 */

typedef uint64_t                vm_object_offset_t;
typedef uint64_t                vm_object_size_t;




typedef mach_port_t             upl_t;
typedef mach_port_t             vm_named_entry_t;


#define UPL_NULL                ((upl_t) 0)
#define VM_NAMED_ENTRY_NULL     ((vm_named_entry_t) 0)

#endif  /* _MACH_VM_TYPES_H_ */
