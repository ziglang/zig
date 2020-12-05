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
#ifndef _ARM_ARCH_H
#define _ARM_ARCH_H

/* Collect the __ARM_ARCH_*__ compiler flags into something easier to use. */
#if defined (__ARM_ARCH_7A__) || defined (__ARM_ARCH_7S__) || defined (__ARM_ARCH_7F__) || defined (__ARM_ARCH_7K__)
#define _ARM_ARCH_7
#endif

#if defined (_ARM_ARCH_7) || defined (__ARM_ARCH_6K__) || defined (__ARM_ARCH_6ZK__)
#define _ARM_ARCH_6K
#endif

#if defined (_ARM_ARCH_7) || defined (__ARM_ARCH_6Z__) || defined (__ARM_ARCH_6ZK__)
#define _ARM_ARCH_6Z
#endif

#if defined (__ARM_ARCH_6__) || defined (__ARM_ARCH_6J__) || \
        defined (_ARM_ARCH_6Z) || defined (_ARM_ARCH_6K)
#define _ARM_ARCH_6
#endif

#if defined (_ARM_ARCH_6) || defined (__ARM_ARCH_5E__) || \
        defined (__ARM_ARCH_5TE__) || defined (__ARM_ARCH_5TEJ__)
#define _ARM_ARCH_5E
#endif

#if defined (_ARM_ARCH_5E) || defined (__ARM_ARCH_5__) || \
        defined (__ARM_ARCH_5T__)
#define _ARM_ARCH_5
#endif

#if defined (_ARM_ARCH_5) || defined (__ARM_ARCH_4T__)
#define _ARM_ARCH_4T
#endif

#if defined (_ARM_ARCH_4T) || defined (__ARM_ARCH_4__)
#define _ARM_ARCH_4
#endif

#endif
