/*
 * Copyright (c) 2015 Apple Computer, Inc. All rights reserved.
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

#ifndef _MACH_THREAD_STATE_H_
#define _MACH_THREAD_STATE_H_

#include <Availability.h>
#include <mach/mach.h>

#ifndef KERNEL
/*
 * Gets all register values in the target thread with pointer-like contents.
 *
 * There is no guarantee that the returned values are valid pointers, but all
 * valid pointers will be returned.  The order and count of the provided
 * register values is unspecified and may change; registers with values that
 * are not valid pointers may be omitted, so the number of pointers returned
 * may vary from call to call.
 *
 * sp is an out parameter that will contain the stack pointer.
 * length is an in/out parameter for the length of the values array.
 * values is an array of pointers.
 *
 * This may only be called on threads in the current task.  If the current
 * platform defines a stack red zone, the stack pointer returned will be
 * adjusted to account for red zone.
 *
 * If length is insufficient, KERN_INSUFFICIENT_BUFFER_SIZE will be returned
 * and length set to the amount of memory required.  Callers MUST NOT assume
 * that any particular size of buffer will be sufficient and should retry with
 * an appropriately sized buffer upon this error.
 */
__API_AVAILABLE(macosx(10.14), ios(12.0), tvos(9.0), watchos(5.0))
kern_return_t thread_get_register_pointer_values(thread_t thread,
    uintptr_t *sp, size_t *length, uintptr_t *values);
#endif

#endif /* _MACH_THREAD_STATE_H_ */