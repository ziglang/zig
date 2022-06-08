/*
 * Copyright (c) 2000-2004 Apple Computer, Inc. All rights reserved.
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
 * Copyright (c) 1991,1990,1989 Carnegie Mellon University
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
 */
/*
 *	Author: David B. Golub, Carnegie Mellon University
 *	Date:   3/89
 */

#ifndef DEVICE_TYPES_H
#define DEVICE_TYPES_H

/*
 * Types for device interface.
 */
#include <mach/std_types.h>
#include <mach/mach_types.h>
#include <mach/message.h>
#include <mach/port.h>
#include <stdint.h>



/*
 * IO buffer - out-of-line array of characters.
 */
typedef char *  io_buf_ptr_t;

/*
 * Some types for IOKit.
 */


/* must match device_types.defs */
typedef char                    io_name_t[128];
typedef char                    io_string_t[512];
typedef char                    io_string_inband_t[4096];
typedef char                    io_struct_inband_t[4096];

#if   __LP64__
typedef uint64_t                io_user_scalar_t;
typedef uint64_t                io_user_reference_t;
typedef io_user_scalar_t        io_scalar_inband_t[16];
typedef io_user_reference_t     io_async_ref_t[8];
typedef io_user_scalar_t        io_scalar_inband64_t[16];
typedef io_user_reference_t     io_async_ref64_t[8];
#else
typedef int                     io_user_scalar_t;
typedef natural_t               io_user_reference_t;
typedef io_user_scalar_t        io_scalar_inband_t[16];
typedef io_user_reference_t     io_async_ref_t[8];
typedef uint64_t                io_scalar_inband64_t[16];
typedef uint64_t                io_async_ref64_t[8];
#endif // __LP64__


#ifndef __IOKIT_PORTS_DEFINED__
#define __IOKIT_PORTS_DEFINED__
typedef mach_port_t     io_object_t;
#endif  /* __IOKIT_PORTS_DEFINED__ */



#endif  /* DEVICE_TYPES_H */