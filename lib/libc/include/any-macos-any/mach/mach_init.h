/*
 * Copyright (c) 1999 Apple Computer, Inc. All rights reserved.
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
 * Mach Operating System
 * Copyright (c) 1991,1990,1989,1988,1987,1986 Carnegie Mellon University
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
 *	Items provided by the Mach environment initialization.
 */

#ifndef _MACH_INIT_
#define _MACH_INIT_     1

#include <mach/mach_types.h>
#include <mach/vm_page_size.h>
#include <stdarg.h>

#include <sys/cdefs.h>

#ifndef KERNEL
#include <Availability.h>
#endif

/*
 *	Kernel-related ports; how a task/thread controls itself
 */

__BEGIN_DECLS
extern mach_port_t mach_host_self(void);
extern mach_port_t mach_thread_self(void);
__API_AVAILABLE(macos(11.3), ios(14.5), tvos(14.5), watchos(7.3))
extern boolean_t mach_task_is_self(task_name_t task);
extern kern_return_t host_page_size(host_t, vm_size_t *);

extern mach_port_t      mach_task_self_;
#define mach_task_self() mach_task_self_
#define current_task()  mach_task_self()

__END_DECLS
#include <mach/mach_traps.h>
__BEGIN_DECLS

/*
 *	Other important ports in the Mach user environment
 */

extern  mach_port_t     bootstrap_port;

/*
 *	Where these ports occur in the "mach_ports_register"
 *	collection... only servers or the runtime library need know.
 */

#define NAME_SERVER_SLOT        0
#define ENVIRONMENT_SLOT        1
#define SERVICE_SLOT            2

#define MACH_PORTS_SLOTS_USED   3

/*
 *	fprintf_stderr uses vprintf_stderr_func to produce
 *	error messages, this can be overridden by a user
 *	application to point to a user-specified output function
 */
extern int (*vprintf_stderr_func)(const char *format, va_list ap);

__END_DECLS

#endif  /* _MACH_INIT_ */