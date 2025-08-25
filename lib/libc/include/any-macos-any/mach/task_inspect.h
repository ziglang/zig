/*
 * Copyright (c) 2017 Apple Inc. All rights reserved.
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

#ifndef MACH_TASK_INSPECT_H
#define MACH_TASK_INSPECT_H

#include <stdint.h>
#include <mach/vm_types.h>

/*
 * XXX These interfaces are still in development -- they are subject to change
 * without notice.
 */

typedef natural_t task_inspect_flavor_t;

enum task_inspect_flavor {
	TASK_INSPECT_BASIC_COUNTS = 1,
};

struct task_inspect_basic_counts {
	uint64_t instructions;
	uint64_t cycles;
};
#define TASK_INSPECT_BASIC_COUNTS_COUNT \
	(sizeof(struct task_inspect_basic_counts) / sizeof(natural_t))
typedef struct task_inspect_basic_counts task_inspect_basic_counts_data_t;
typedef struct task_inspect_basic_counts *task_inspect_basic_counts_t;

typedef integer_t *task_inspect_info_t;

#endif /* !defined(MACH_TASK_INSPECT_H) */
