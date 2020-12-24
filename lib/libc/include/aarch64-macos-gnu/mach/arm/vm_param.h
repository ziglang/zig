/*
 * Copyright (c) 2007 Apple Inc. All rights reserved.
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
 * FILE_ID: vm_param.h
 */

/*
 *	ARM machine dependent virtual memory parameters.
 */

#ifndef _MACH_ARM_VM_PARAM_H_
#define _MACH_ARM_VM_PARAM_H_


#if !defined (KERNEL) && !defined (__ASSEMBLER__)
#include <mach/vm_page_size.h>
#endif

#define BYTE_SIZE       8       /* byte size in bits */


#define PAGE_SHIFT                      vm_page_shift
#define PAGE_SIZE                       vm_page_size
#define PAGE_MASK                       vm_page_mask

#define VM_PAGE_SIZE            vm_page_size

#define machine_ptob(x)         ((x) << PAGE_SHIFT)


#define PAGE_MAX_SHIFT          14
#define PAGE_MAX_SIZE           (1 << PAGE_MAX_SHIFT)
#define PAGE_MAX_MASK           (PAGE_MAX_SIZE-1)

#define PAGE_MIN_SHIFT          12
#define PAGE_MIN_SIZE           (1 << PAGE_MIN_SHIFT)
#define PAGE_MIN_MASK           (PAGE_MIN_SIZE-1)

#define VM_MAX_PAGE_ADDRESS     MACH_VM_MAX_ADDRESS

#ifndef __ASSEMBLER__


#if defined (__arm__)

#define VM_MIN_ADDRESS          ((vm_address_t) 0x00000000)
#define VM_MAX_ADDRESS          ((vm_address_t) 0x80000000)

/* system-wide values */
#define MACH_VM_MIN_ADDRESS     ((mach_vm_offset_t) 0)
#define MACH_VM_MAX_ADDRESS     ((mach_vm_offset_t) VM_MAX_ADDRESS)

#elif defined (__arm64__)

#define VM_MIN_ADDRESS          ((vm_address_t) 0x0000000000000000ULL)
#define VM_MAX_ADDRESS          ((vm_address_t) 0x0000000080000000ULL)

/* system-wide values */
#define MACH_VM_MIN_ADDRESS_RAW 0x0ULL
#define MACH_VM_MAX_ADDRESS_RAW 0x00007FFFFE000000ULL

#define MACH_VM_MIN_ADDRESS     ((mach_vm_offset_t) MACH_VM_MIN_ADDRESS_RAW)
#define MACH_VM_MAX_ADDRESS     ((mach_vm_offset_t) MACH_VM_MAX_ADDRESS_RAW)


#else /* defined(__arm64__) */
#error architecture not supported
#endif

#define VM_MAP_MIN_ADDRESS      VM_MIN_ADDRESS
#define VM_MAP_MAX_ADDRESS      VM_MAX_ADDRESS


#endif  /* !__ASSEMBLER__ */

#define SWI_SYSCALL     0x80

#endif  /* _MACH_ARM_VM_PARAM_H_ */