/*
 * Copyright (c) 2008 Apple Computer, Inc. All rights reserved.
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

#ifndef _I386__PARAM_H_
#define _I386__PARAM_H_

#if defined (__i386__) || defined (__x86_64__)

#include <i386/_types.h>

/*
 * Round p (pointer or byte index) up to a correctly-aligned value for all
 * data types (int, long, ...).   The result is unsigned int and must be
 * cast to any desired pointer type.
 */
#define __DARWIN_ALIGNBYTES     (sizeof(__darwin_size_t) - 1)
#define __DARWIN_ALIGN(p)       ((__darwin_size_t)((__darwin_size_t)(p) + __DARWIN_ALIGNBYTES) &~ __DARWIN_ALIGNBYTES)

#define      __DARWIN_ALIGNBYTES32     (sizeof(__uint32_t) - 1)
#define       __DARWIN_ALIGN32(p)       ((__darwin_size_t)((__darwin_size_t)(p) + __DARWIN_ALIGNBYTES32) &~ __DARWIN_ALIGNBYTES32)

#endif /* defined (__i386__) || defined (__x86_64__) */

#endif /* _I386__PARAM_H_ */
