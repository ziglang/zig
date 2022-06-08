/*
 * Copyright (c) 2001-2005 Apple Computer, Inc. All rights reserved.
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

#ifndef _MACH_MACH_TIME_H_
#define _MACH_MACH_TIME_H_

#include <mach/mach_types.h>
#include <sys/cdefs.h>
#include <Availability.h>

struct mach_timebase_info {
	uint32_t        numer;
	uint32_t        denom;
};

typedef struct mach_timebase_info       *mach_timebase_info_t;
typedef struct mach_timebase_info       mach_timebase_info_data_t;

__BEGIN_DECLS

kern_return_t           mach_timebase_info(
	mach_timebase_info_t    info);

kern_return_t           mach_wait_until(
	uint64_t                deadline);


uint64_t                        mach_absolute_time(void);

__OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_8_0)
uint64_t                        mach_approximate_time(void);

/*
 * like mach_absolute_time, but advances during sleep
 */
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0)
uint64_t                        mach_continuous_time(void);

/*
 * like mach_approximate_time, but advances during sleep
 */
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0)
uint64_t                        mach_continuous_approximate_time(void);


__END_DECLS

#endif /* _MACH_MACH_TIME_H_ */