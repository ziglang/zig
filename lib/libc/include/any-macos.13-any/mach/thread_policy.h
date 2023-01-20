/*
 * Copyright (c) 2000-2007 Apple Inc. All rights reserved.
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

#ifndef _MACH_THREAD_POLICY_H_
#define _MACH_THREAD_POLICY_H_

#include <mach/mach_types.h>

/*
 * These are the calls for accessing the policy parameters
 * of a particular thread.
 *
 * The extra 'get_default' parameter to the second call is
 * IN/OUT as follows:
 * 1) if asserted on the way in it indicates that the default
 * values should be returned, not the ones currently set, in
 * this case 'get_default' will always be asserted on return;
 * 2) if unasserted on the way in, the current settings are
 * desired and if still unasserted on return, then the info
 * returned reflects the current settings, otherwise if
 * 'get_default' returns asserted, it means that there are no
 * current settings due to other parameters taking precedence,
 * and the default ones are being returned instead.
 */

typedef natural_t       thread_policy_flavor_t;
typedef integer_t       *thread_policy_t;

/*
 *  kern_return_t	thread_policy_set(
 *                                       thread_t					thread,
 *                                       thread_policy_flavor_t		flavor,
 *                                       thread_policy_t				policy_info,
 *                                       mach_msg_type_number_t		count);
 *
 *  kern_return_t	thread_policy_get(
 *                                       thread_t					thread,
 *                                       thread_policy_flavor_t		flavor,
 *                                       thread_policy_t				policy_info,
 *                                       mach_msg_type_number_t		*count,
 *                                       boolean_t					*get_default);
 */

/*
 * Defined flavors.
 */
/*
 * THREAD_STANDARD_POLICY:
 *
 * This is the standard (fair) scheduling mode, assigned to new
 * threads.  The thread will be given processor time in a manner
 * which apportions approximately equal share to long running
 * computations.
 *
 * Parameters:
 *	[none]
 */

#define THREAD_STANDARD_POLICY                  1

struct thread_standard_policy {
	natural_t               no_data;
};

typedef struct thread_standard_policy   thread_standard_policy_data_t;
typedef struct thread_standard_policy   *thread_standard_policy_t;

#define THREAD_STANDARD_POLICY_COUNT    0

/*
 * THREAD_EXTENDED_POLICY:
 *
 * Extended form of THREAD_STANDARD_POLICY, which supplies a
 * hint indicating whether this is a long running computation.
 *
 * Parameters:
 *
 * timeshare: TRUE (the default) results in identical scheduling
 * behavior as THREAD_STANDARD_POLICY.
 */

#define THREAD_EXTENDED_POLICY                  1

struct thread_extended_policy {
	boolean_t               timeshare;
};

typedef struct thread_extended_policy   thread_extended_policy_data_t;
typedef struct thread_extended_policy   *thread_extended_policy_t;

#define THREAD_EXTENDED_POLICY_COUNT    ((mach_msg_type_number_t) \
	(sizeof (thread_extended_policy_data_t) / sizeof (integer_t)))

/*
 * THREAD_TIME_CONSTRAINT_POLICY:
 *
 * This scheduling mode is for threads which have real time
 * constraints on their execution.
 *
 * Parameters:
 *
 * period: This is the nominal amount of time between separate
 * processing arrivals, specified in absolute time units.  A
 * value of 0 indicates that there is no inherent periodicity in
 * the computation.
 *
 * computation: This is the nominal amount of computation
 * time needed during a separate processing arrival, specified
 * in absolute time units.  The thread may be preempted after
 * the computation time has elapsed.
 * If (computation < constraint/2) it will be forced to
 * constraint/2 to avoid unintended preemption and associated
 * timer interrupts.
 *
 * constraint: This is the maximum amount of real time that
 * may elapse from the start of a separate processing arrival
 * to the end of computation for logically correct functioning,
 * specified in absolute time units.  Must be (>= computation).
 * Note that latency = (constraint - computation).
 *
 * preemptible: IGNORED (This indicates that the computation may be
 * interrupted, subject to the constraint specified above.)
 */

#define THREAD_TIME_CONSTRAINT_POLICY           2

struct thread_time_constraint_policy {
	uint32_t                period;
	uint32_t                computation;
	uint32_t                constraint;
	boolean_t               preemptible;
};

typedef struct thread_time_constraint_policy    \
        thread_time_constraint_policy_data_t;
typedef struct thread_time_constraint_policy    \
        *thread_time_constraint_policy_t;

#define THREAD_TIME_CONSTRAINT_POLICY_COUNT     ((mach_msg_type_number_t) \
	(sizeof (thread_time_constraint_policy_data_t) / sizeof (integer_t)))

/*
 * THREAD_PRECEDENCE_POLICY:
 *
 * This may be used to indicate the relative value of the
 * computation compared to the other threads in the task.
 *
 * Parameters:
 *
 * importance: The importance is specified as a signed value.
 */

#define THREAD_PRECEDENCE_POLICY                3

struct thread_precedence_policy {
	integer_t               importance;
};

typedef struct thread_precedence_policy         thread_precedence_policy_data_t;
typedef struct thread_precedence_policy         *thread_precedence_policy_t;

#define THREAD_PRECEDENCE_POLICY_COUNT  ((mach_msg_type_number_t) \
	(sizeof (thread_precedence_policy_data_t) / sizeof (integer_t)))

/*
 * THREAD_AFFINITY_POLICY:
 *
 * This policy is experimental.
 * This may be used to express affinity relationships
 * between threads in the task. Threads with the same affinity tag will
 * be scheduled to share an L2 cache if possible. That is, affinity tags
 * are a hint to the scheduler for thread placement.
 *
 * The namespace of affinity tags is generally local to one task. However,
 * a child task created after the assignment of affinity tags by its parent
 * will share that namespace. In particular, a family of forked processes
 * may be created with a shared affinity namespace.
 *
 * Parameters:
 * tag: The affinity set identifier.
 */

#define THREAD_AFFINITY_POLICY          4

struct thread_affinity_policy {
	integer_t       affinity_tag;
};

#define THREAD_AFFINITY_TAG_NULL                0

typedef struct thread_affinity_policy           thread_affinity_policy_data_t;
typedef struct thread_affinity_policy           *thread_affinity_policy_t;

#define THREAD_AFFINITY_POLICY_COUNT    ((mach_msg_type_number_t) \
	(sizeof (thread_affinity_policy_data_t) / sizeof (integer_t)))

/*
 * THREAD_BACKGROUND_POLICY:
 */

#define THREAD_BACKGROUND_POLICY        5

struct thread_background_policy {
	integer_t       priority;
};

#define THREAD_BACKGROUND_POLICY_DARWIN_BG 0x1000

typedef struct thread_background_policy         thread_background_policy_data_t;
typedef struct thread_background_policy         *thread_background_policy_t;

#define THREAD_BACKGROUND_POLICY_COUNT  ((mach_msg_type_number_t) \
	(sizeof (thread_background_policy_data_t) / sizeof (integer_t)))


#define THREAD_LATENCY_QOS_POLICY       7
typedef integer_t       thread_latency_qos_t;

struct thread_latency_qos_policy {
	thread_latency_qos_t thread_latency_qos_tier;
};

typedef struct thread_latency_qos_policy        thread_latency_qos_policy_data_t;
typedef struct thread_latency_qos_policy        *thread_latency_qos_policy_t;

#define THREAD_LATENCY_QOS_POLICY_COUNT ((mach_msg_type_number_t)       \
	    (sizeof (thread_latency_qos_policy_data_t) / sizeof (integer_t)))

#define THREAD_THROUGHPUT_QOS_POLICY    8
typedef integer_t       thread_throughput_qos_t;

struct thread_throughput_qos_policy {
	thread_throughput_qos_t thread_throughput_qos_tier;
};

typedef struct thread_throughput_qos_policy     thread_throughput_qos_policy_data_t;
typedef struct thread_throughput_qos_policy     *thread_throughput_qos_policy_t;

#define THREAD_THROUGHPUT_QOS_POLICY_COUNT      ((mach_msg_type_number_t) \
	    (sizeof (thread_throughput_qos_policy_data_t) / sizeof (integer_t)))


#endif  /* _MACH_THREAD_POLICY_H_ */