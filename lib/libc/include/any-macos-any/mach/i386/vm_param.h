/*
 * Copyright (c) 2000-2012 Apple Inc. All rights reserved.
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
 * Mach Operating System
 * Copyright (c) 1991,1990,1989,1988 Carnegie Mellon University
 * All Rights Reserved.
 *
 * Permission to use, copy, modify and distribute this software and its
 * documentation is hereby granted, provided that both the copyright
 * notice and this permission notice appear in all copies of the
 * software, derivative works or modified versions, and any portions
 * thereof, and that both notices appear in supporting documentation.
 *
 * CARNEGIE MELLON ALLOWS FREE USE OF THIS SOFTWARE IN ITS "AS IS"
 * CONDITION.  CARNEGIE MELLON DISCLAIMS ANY LIABILITY OF ANY KIND FOR
 * ANY DAMAGES WHATSOEVER RESULTING FROM THE USE OF THIS SOFTWARE.
 *
 * Carnegie Mellon requests users of this software to return to
 *
 *  Software Distribution Coordinator  or  Software.Distribution@CS.CMU.EDU
 *  School of Computer Science
 *  Carnegie Mellon University
 *  Pittsburgh PA 15213-3890
 *
 * any improvements or extensions that they make and grant Carnegie Mellon
 * the rights to redistribute these changes.
 */

/*
 * Copyright (c) 1994 The University of Utah and
 * the Computer Systems Laboratory at the University of Utah (CSL).
 * All rights reserved.
 *
 * Permission to use, copy, modify and distribute this software is hereby
 * granted provided that (1) source code retains these copyright, permission,
 * and disclaimer notices, and (2) redistributions including binaries
 * reproduce the notices in supporting documentation, and (3) all advertising
 * materials mentioning features or use of this software display the following
 * acknowledgement: ``This product includes software developed by the
 * Computer Systems Laboratory at the University of Utah.''
 *
 * THE UNIVERSITY OF UTAH AND CSL ALLOW FREE USE OF THIS SOFTWARE IN ITS "AS
 * IS" CONDITION.  THE UNIVERSITY OF UTAH AND CSL DISCLAIM ANY LIABILITY OF
 * ANY KIND FOR ANY DAMAGES WHATSOEVER RESULTING FROM THE USE OF THIS SOFTWARE.
 *
 * CSL requests users of this software to return to csl-dist@cs.utah.edu any
 * improvements that they make and grant CSL redistribution rights.
 *
 */

/*
 *	File:	vm_param.h
 *	Author:	Avadis Tevanian, Jr.
 *	Date:	1985
 *
 *	I386 machine dependent virtual memory parameters.
 *	Most of the declarations are preceeded by I386_ (or i386_)
 *	which is OK because only I386 specific code will be using
 *	them.
 */

#ifndef _MACH_I386_VM_PARAM_H_
#define _MACH_I386_VM_PARAM_H_

#if defined (__i386__) || defined (__x86_64__)

#if !defined(KERNEL) && !defined(__ASSEMBLER__)

#include <mach/vm_page_size.h>
#endif

#define BYTE_SIZE               8               /* byte size in bits */

#define I386_PGBYTES            4096            /* bytes per 80386 page */
#define I386_PGSHIFT            12              /* bitshift for pages */


#if !defined(__MAC_OS_X_VERSION_MIN_REQUIRED) || (__MAC_OS_X_VERSION_MIN_REQUIRED < 101600)
#define PAGE_SHIFT              I386_PGSHIFT
#define PAGE_SIZE               I386_PGBYTES
#define PAGE_MASK               (PAGE_SIZE-1)
#else /* !defined(__MAC_OS_X_VERSION_MIN_REQUIRED) || (__MAC_OS_X_VERSION_MIN_REQUIRED < 101600) */
#define PAGE_SHIFT              vm_page_shift
#define PAGE_SIZE               vm_page_size
#define PAGE_MASK               vm_page_mask
#endif /* !defined(__MAC_OS_X_VERSION_MIN_REQUIRED) || (__MAC_OS_X_VERSION_MIN_REQUIRED < 101600) */

#define PAGE_MAX_SHIFT          14
#define PAGE_MAX_SIZE           (1 << PAGE_MAX_SHIFT)
#define PAGE_MAX_MASK           (PAGE_MAX_SIZE-1)

#define PAGE_MIN_SHIFT          12
#define PAGE_MIN_SIZE           (1 << PAGE_MIN_SHIFT)
#define PAGE_MIN_MASK           (PAGE_MIN_SIZE-1)


#define VM_MIN_ADDRESS64        ((user_addr_t) 0x0000000000000000ULL)
/*
 * Default top of user stack, grows down from here.
 * Address chosen to be 1G (3rd level page table entry) below SHARED_REGION_BASE_X86_64
 * minus additional 1Meg (1/2 1st level page table coverage) to allow a redzone after it.
 */
#define VM_USRSTACK64           ((user_addr_t) (0x00007FF7C0000000ull - (1024 * 1024)))

/*
 * XXX TODO: Obsolete?
 */
#define VM_DYLD64               ((user_addr_t) 0x00007FFF5FC00000ULL)
#define VM_LIB64_SHR_DATA       ((user_addr_t) 0x00007FFF60000000ULL)
#define VM_LIB64_SHR_TEXT       ((user_addr_t) 0x00007FFF80000000ULL)
/*
 * the end of the usable user address space , for now about 47 bits.
 * the 64 bit commpage is past the end of this
 */
#define VM_MAX_PAGE_ADDRESS     ((user_addr_t) 0x00007FFFFFE00000ULL)
/*
 * canonical end of user address space for limits checking
 */
#define VM_MAX_USER_PAGE_ADDRESS ((user_addr_t)0x00007FFFFFFFF000ULL)


/* system-wide values */
#define MACH_VM_MIN_ADDRESS             ((mach_vm_offset_t) 0)
#define MACH_VM_MAX_ADDRESS             ((mach_vm_offset_t) VM_MAX_PAGE_ADDRESS)

/* process-relative values (all 32-bit legacy only for now) */
#define VM_MIN_ADDRESS          ((vm_offset_t) 0)
#define VM_USRSTACK32           ((vm_offset_t) 0xC0000000)      /* ASLR slides stack down by up to 1 MB */
#define VM_MAX_ADDRESS          ((vm_offset_t) 0xFFE00000)



#endif /* defined (__i386__) || defined (__x86_64__) */

#endif  /* _MACH_I386_VM_PARAM_H_ */
