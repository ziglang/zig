/*
 * Copyright (c) 2000-2002 Apple Computer, Inc. All rights reserved.
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
 */
/*
 *	File:	mach/vm_behavior.h
 *
 *	Virtual memory map behavior definitions.
 *
 */

#ifndef _MACH_VM_BEHAVIOR_H_
#define _MACH_VM_BEHAVIOR_H_

/*
 *	Types defined:
 *
 *	vm_behavior_t	behavior codes.
 */

typedef int             vm_behavior_t;

/*
 *	Enumeration of valid values for vm_behavior_t.
 *	These describe expected page reference behavior for
 *	for a given range of virtual memory.  For implementation
 *	details see vm/vm_fault.c
 */


/*
 * The following behaviors affect the memory region's future behavior
 * and are stored in the VM map entry data structure.
 */
#define VM_BEHAVIOR_DEFAULT     ((vm_behavior_t) 0)     /* default */
#define VM_BEHAVIOR_RANDOM      ((vm_behavior_t) 1)     /* random */
#define VM_BEHAVIOR_SEQUENTIAL  ((vm_behavior_t) 2)     /* forward sequential */
#define VM_BEHAVIOR_RSEQNTL     ((vm_behavior_t) 3)     /* reverse sequential */

/*
 * The following "behaviors" affect the memory region only at the time of the
 * call and are not stored in the VM map entry.
 */
#define VM_BEHAVIOR_WILLNEED    ((vm_behavior_t) 4)     /* will need in near future */
#define VM_BEHAVIOR_DONTNEED    ((vm_behavior_t) 5)     /* dont need in near future */
#define VM_BEHAVIOR_FREE        ((vm_behavior_t) 6)     /* free memory without write-back */
#define VM_BEHAVIOR_ZERO_WIRED_PAGES    ((vm_behavior_t) 7)     /* zero out the wired pages of an entry if it is being deleted without unwiring them first */
#define VM_BEHAVIOR_REUSABLE    ((vm_behavior_t) 8)
#define VM_BEHAVIOR_REUSE       ((vm_behavior_t) 9)
#define VM_BEHAVIOR_CAN_REUSE   ((vm_behavior_t) 10)
#define VM_BEHAVIOR_PAGEOUT     ((vm_behavior_t) 11)

#endif  /*_MACH_VM_BEHAVIOR_H_*/