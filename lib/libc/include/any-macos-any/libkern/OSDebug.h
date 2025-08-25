/*
 * Copyright (c) 2000 Apple Computer, Inc. All rights reserved.
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
 * Copyright (c) 1999 Apple Computer, Inc.  All rights reserved.
 *
 * HISTORY
 *
 */

#ifndef _OS_OSDEBBUG_H
#define _OS_OSDEBBUG_H

#include <sys/cdefs.h>
#include <mach/mach_types.h>

__BEGIN_DECLS

/* Report a message with a 4 entry backtrace - very slow */
extern void OSReportWithBacktrace(const char *str, ...) __printflike(1, 2);
extern unsigned OSBacktrace(void **bt, unsigned maxAddrs);

/* Simple dump of 20 backtrace entries */
extern void OSPrintBacktrace(void);

/*! @function OSKernelStackRemaining
 *   @abstract Returns bytes available below the current stack frame.
 *   @discussion Returns bytes available below the current stack frame. Safe for interrupt or thread context.
 *   @result Approximate byte count available. */

vm_offset_t OSKernelStackRemaining( void );

__END_DECLS

#endif /* !_OS_OSDEBBUG_H */
