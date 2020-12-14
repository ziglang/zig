/*
 * Copyright (c) 2000-2005, 2015 Apple Computer, Inc. All rights reserved.
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
 * Copyright (c) 1991,1990,1989,1988,1987 Carnegie Mellon University
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
 *	File:	mach/thread_info
 *
 *	Thread information structure and definitions.
 *
 *	The defintions in this file are exported to the user.  The kernel
 *	will translate its internal data structures to these structures
 *	as appropriate.
 *
 */

#ifndef _MACH_THREAD_INFO_H_
#define _MACH_THREAD_INFO_H_

#include <mach/boolean.h>
#include <mach/policy.h>
#include <mach/time_value.h>
#include <mach/message.h>
#include <mach/machine/vm_types.h>

/*
 *	Generic information structure to allow for expansion.
 */
typedef natural_t       thread_flavor_t;
typedef integer_t       *thread_info_t;         /* varying array of int */

#define THREAD_INFO_MAX         (32)    /* maximum array size */
typedef integer_t       thread_info_data_t[THREAD_INFO_MAX];

/*
 *	Currently defined information.
 */
#define THREAD_BASIC_INFO               3     /* basic information */

struct thread_basic_info {
	time_value_t    user_time;      /* user run time */
	time_value_t    system_time;    /* system run time */
	integer_t       cpu_usage;      /* scaled cpu usage percentage */
	policy_t        policy;         /* scheduling policy in effect */
	integer_t       run_state;      /* run state (see below) */
	integer_t       flags;          /* various flags (see below) */
	integer_t       suspend_count;  /* suspend count for thread */
	integer_t       sleep_time;     /* number of seconds that thread
	                                 *  has been sleeping */
};

typedef struct thread_basic_info  thread_basic_info_data_t;
typedef struct thread_basic_info  *thread_basic_info_t;
#define THREAD_BASIC_INFO_COUNT   ((mach_msg_type_number_t) \
	        (sizeof(thread_basic_info_data_t) / sizeof(natural_t)))

#define THREAD_IDENTIFIER_INFO          4     /* thread id and other information */

struct thread_identifier_info {
	uint64_t        thread_id;      /* system-wide unique 64-bit thread id */
	uint64_t        thread_handle;  /* handle to be used by libproc */
	uint64_t        dispatch_qaddr; /* libdispatch queue address */
};

typedef struct thread_identifier_info  thread_identifier_info_data_t;
typedef struct thread_identifier_info  *thread_identifier_info_t;
#define THREAD_IDENTIFIER_INFO_COUNT   ((mach_msg_type_number_t) \
	        (sizeof(thread_identifier_info_data_t) / sizeof(natural_t)))

/*
 *	Scale factor for usage field.
 */

#define TH_USAGE_SCALE  1000

/*
 *	Thread run states (state field).
 */

#define TH_STATE_RUNNING        1       /* thread is running normally */
#define TH_STATE_STOPPED        2       /* thread is stopped */
#define TH_STATE_WAITING        3       /* thread is waiting normally */
#define TH_STATE_UNINTERRUPTIBLE 4      /* thread is in an uninterruptible
	                                 *  wait */
#define TH_STATE_HALTED         5       /* thread is halted at a
	                                 *  clean point */

/*
 *	Thread flags (flags field).
 */
#define TH_FLAGS_SWAPPED        0x1     /* thread is swapped out */
#define TH_FLAGS_IDLE           0x2     /* thread is an idle thread */
#define TH_FLAGS_GLOBAL_FORCED_IDLE     0x4     /* thread performs global forced idle */

/*
 *  Thread extended info (returns same info as proc_pidinfo(...,PROC_PIDTHREADINFO,...)
 */
#define THREAD_EXTENDED_INFO 5
#define MAXTHREADNAMESIZE 64
struct thread_extended_info {           // same as proc_threadinfo (from proc_info.h) & proc_threadinfo_internal (from bsd_taskinfo.h)
	uint64_t                pth_user_time;          /* user run time */
	uint64_t                pth_system_time;        /* system run time */
	int32_t                 pth_cpu_usage;          /* scaled cpu usage percentage */
	int32_t                 pth_policy;                     /* scheduling policy in effect */
	int32_t                 pth_run_state;          /* run state (see below) */
	int32_t                 pth_flags;              /* various flags (see below) */
	int32_t                 pth_sleep_time;         /* number of seconds that thread */
	int32_t                 pth_curpri;                     /* cur priority*/
	int32_t                 pth_priority;           /*  priority*/
	int32_t                 pth_maxpriority;        /* max priority*/
	char                    pth_name[MAXTHREADNAMESIZE];    /* thread name, if any */
};
typedef struct thread_extended_info thread_extended_info_data_t;
typedef struct thread_extended_info * thread_extended_info_t;
#define THREAD_EXTENDED_INFO_COUNT  ((mach_msg_type_number_t) \
	        (sizeof(thread_extended_info_data_t) / sizeof (natural_t)))

#define THREAD_DEBUG_INFO_INTERNAL 6    /* for kernel development internal info */


#define IO_NUM_PRIORITIES       4

#define UPDATE_IO_STATS(info, size)                             \
{                                                               \
	info.count++;                                           \
	info.size += size;                                      \
}

#define UPDATE_IO_STATS_ATOMIC(info, io_size)                   \
{                                                               \
	OSIncrementAtomic64((SInt64 *)&(info.count));           \
	OSAddAtomic64(io_size, (SInt64 *)&(info.size));         \
}

struct io_stat_entry {
	uint64_t        count;
	uint64_t        size;
};

struct io_stat_info {
	struct io_stat_entry    disk_reads;
	struct io_stat_entry    io_priority[IO_NUM_PRIORITIES];
	struct io_stat_entry    paging;
	struct io_stat_entry    metadata;
	struct io_stat_entry    total_io;
};

typedef struct io_stat_info *io_stat_info_t;


/*
 * Obsolete interfaces.
 */

#define THREAD_SCHED_TIMESHARE_INFO     10
#define THREAD_SCHED_RR_INFO            11
#define THREAD_SCHED_FIFO_INFO          12

#endif  /* _MACH_THREAD_INFO_H_ */