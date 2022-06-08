/*
 * Copyright (c) 2000-2005 Apple Computer, Inc. All rights reserved.
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
 */

#ifndef _MACH_POLICY_H_
#define _MACH_POLICY_H_

/*
 *	mach/policy.h
 *
 *	Definitions for scheduing policy.
 */

/*
 *  All interfaces defined here are obsolete.
 */

#include <mach/boolean.h>
#include <mach/message.h>
#include <mach/vm_types.h>

/*
 *	Old scheduling control interface
 */
typedef int                             policy_t;
typedef integer_t                       *policy_info_t;
typedef integer_t                       *policy_base_t;
typedef integer_t                       *policy_limit_t;

/*
 *	Policy definitions.  Policies should be powers of 2,
 *	but cannot be or'd together other than to test for a
 *	policy 'class'.
 */
#define POLICY_NULL             0       /* none			*/
#define POLICY_TIMESHARE        1       /* timesharing		*/
#define POLICY_RR               2       /* fixed round robin	*/
#define POLICY_FIFO             4       /* fixed fifo		*/

#define __NEW_SCHEDULING_FRAMEWORK__

/*
 *	Check if policy is of 'class' fixed-priority.
 */
#define POLICYCLASS_FIXEDPRI    (POLICY_RR | POLICY_FIFO)

/*
 *	Check if policy is valid.
 */
#define invalid_policy(policy)                  \
	((policy) != POLICY_TIMESHARE &&        \
	 (policy) != POLICY_RR &&               \
	 (policy) != POLICY_FIFO)


/*
 *      Types for TIMESHARE policy
 */
struct policy_timeshare_base {
	integer_t               base_priority;
};
struct policy_timeshare_limit {
	integer_t               max_priority;
};
struct policy_timeshare_info {
	integer_t               max_priority;
	integer_t               base_priority;
	integer_t               cur_priority;
	boolean_t               depressed;
	integer_t               depress_priority;
};

typedef struct policy_timeshare_base    *policy_timeshare_base_t;
typedef struct policy_timeshare_limit   *policy_timeshare_limit_t;
typedef struct policy_timeshare_info    *policy_timeshare_info_t;

typedef struct policy_timeshare_base    policy_timeshare_base_data_t;
typedef struct policy_timeshare_limit   policy_timeshare_limit_data_t;
typedef struct policy_timeshare_info    policy_timeshare_info_data_t;


#define POLICY_TIMESHARE_BASE_COUNT     ((mach_msg_type_number_t) \
	(sizeof(struct policy_timeshare_base)/sizeof(integer_t)))
#define POLICY_TIMESHARE_LIMIT_COUNT    ((mach_msg_type_number_t) \
	(sizeof(struct policy_timeshare_limit)/sizeof(integer_t)))
#define POLICY_TIMESHARE_INFO_COUNT     ((mach_msg_type_number_t) \
	(sizeof(struct policy_timeshare_info)/sizeof(integer_t)))


/*
 *	Types for the ROUND ROBIN (RR) policy
 */
struct policy_rr_base {
	integer_t               base_priority;
	integer_t               quantum;
};
struct policy_rr_limit {
	integer_t               max_priority;
};
struct policy_rr_info {
	integer_t               max_priority;
	integer_t               base_priority;
	integer_t               quantum;
	boolean_t               depressed;
	integer_t               depress_priority;
};

typedef struct policy_rr_base           *policy_rr_base_t;
typedef struct policy_rr_limit          *policy_rr_limit_t;
typedef struct policy_rr_info           *policy_rr_info_t;

typedef struct policy_rr_base           policy_rr_base_data_t;
typedef struct policy_rr_limit          policy_rr_limit_data_t;
typedef struct policy_rr_info           policy_rr_info_data_t;

#define POLICY_RR_BASE_COUNT    ((mach_msg_type_number_t)       \
	(sizeof(struct policy_rr_base)/sizeof(integer_t)))
#define POLICY_RR_LIMIT_COUNT   ((mach_msg_type_number_t)       \
	(sizeof(struct policy_rr_limit)/sizeof(integer_t)))
#define POLICY_RR_INFO_COUNT    ((mach_msg_type_number_t)       \
	(sizeof(struct policy_rr_info)/sizeof(integer_t)))


/*
 *      Types for the FIRST-IN-FIRST-OUT (FIFO) policy
 */
struct policy_fifo_base {
	integer_t               base_priority;
};
struct policy_fifo_limit {
	integer_t               max_priority;
};
struct policy_fifo_info {
	integer_t               max_priority;
	integer_t               base_priority;
	boolean_t               depressed;
	integer_t               depress_priority;
};

typedef struct policy_fifo_base         *policy_fifo_base_t;
typedef struct policy_fifo_limit        *policy_fifo_limit_t;
typedef struct policy_fifo_info         *policy_fifo_info_t;

typedef struct policy_fifo_base         policy_fifo_base_data_t;
typedef struct policy_fifo_limit        policy_fifo_limit_data_t;
typedef struct policy_fifo_info         policy_fifo_info_data_t;

#define POLICY_FIFO_BASE_COUNT  ((mach_msg_type_number_t)       \
	(sizeof(struct policy_fifo_base)/sizeof(integer_t)))
#define POLICY_FIFO_LIMIT_COUNT ((mach_msg_type_number_t)       \
	(sizeof(struct policy_fifo_limit)/sizeof(integer_t)))
#define POLICY_FIFO_INFO_COUNT  ((mach_msg_type_number_t)       \
	(sizeof(struct policy_fifo_info)/sizeof(integer_t)))

/*
 *      Aggregate policy types
 */

struct policy_bases {
	policy_timeshare_base_data_t    ts;
	policy_rr_base_data_t           rr;
	policy_fifo_base_data_t         fifo;
};

struct policy_limits {
	policy_timeshare_limit_data_t   ts;
	policy_rr_limit_data_t          rr;
	policy_fifo_limit_data_t        fifo;
};

struct policy_infos {
	policy_timeshare_info_data_t    ts;
	policy_rr_info_data_t           rr;
	policy_fifo_info_data_t         fifo;
};

typedef struct policy_bases             policy_base_data_t;
typedef struct policy_limits            policy_limit_data_t;
typedef struct policy_infos             policy_info_data_t;

#endif  /* _MACH_POLICY_H_ */