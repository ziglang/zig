/*
 * Copyright (c) 2000-2015 Apple Inc. All rights reserved.
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
 *	File:	mach/host_info.h
 *
 *	Definitions for host_info call.
 */

#ifndef _MACH_HOST_INFO_H_
#define _MACH_HOST_INFO_H_

#include <mach/message.h>
#include <mach/vm_statistics.h>
#include <mach/machine.h>
#include <mach/machine/vm_types.h>
#include <mach/time_value.h>

#include <sys/cdefs.h>

/*
 *	Generic information structure to allow for expansion.
 */
typedef integer_t       *host_info_t;           /* varying array of int. */
typedef integer_t       *host_info64_t;         /* varying array of int. */

#define HOST_INFO_MAX   (1024)          /* max array size */
typedef integer_t       host_info_data_t[HOST_INFO_MAX];

#define KERNEL_VERSION_MAX (512)
typedef char    kernel_version_t[KERNEL_VERSION_MAX];

#define KERNEL_BOOT_INFO_MAX (4096)
typedef char    kernel_boot_info_t[KERNEL_BOOT_INFO_MAX];

/*
 *	Currently defined information.
 */
/* host_info() */
typedef integer_t       host_flavor_t;
#define HOST_BASIC_INFO         1       /* basic info */
#define HOST_SCHED_INFO         3       /* scheduling info */
#define HOST_RESOURCE_SIZES     4       /* kernel struct sizes */
#define HOST_PRIORITY_INFO      5       /* priority information */
#define HOST_SEMAPHORE_TRAPS    7       /* Has semaphore traps */
#define HOST_MACH_MSG_TRAP      8       /* Has mach_msg_trap */
#define HOST_VM_PURGABLE        9       /* purg'e'able memory info */
#define HOST_DEBUG_INFO_INTERNAL 10     /* Used for kernel internal development tests only */
#define HOST_CAN_HAS_DEBUGGER   11
#define HOST_PREFERRED_USER_ARCH 12     /* Get the preferred user-space architecture */


struct host_can_has_debugger_info {
	boolean_t       can_has_debugger;
};
typedef struct host_can_has_debugger_info       host_can_has_debugger_info_data_t;
typedef struct host_can_has_debugger_info       *host_can_has_debugger_info_t;
#define HOST_CAN_HAS_DEBUGGER_COUNT ((mach_msg_type_number_t) \
	        (sizeof(host_can_has_debugger_info_data_t)/sizeof(integer_t)))

#pragma pack(push, 4)

struct host_basic_info {
	integer_t               max_cpus;               /* max number of CPUs possible */
	integer_t               avail_cpus;             /* number of CPUs now available */
	natural_t               memory_size;            /* size of memory in bytes, capped at 2 GB */
	cpu_type_t              cpu_type;               /* cpu type */
	cpu_subtype_t           cpu_subtype;            /* cpu subtype */
	cpu_threadtype_t        cpu_threadtype;         /* cpu threadtype */
	integer_t               physical_cpu;           /* number of physical CPUs now available */
	integer_t               physical_cpu_max;       /* max number of physical CPUs possible */
	integer_t               logical_cpu;            /* number of logical cpu now available */
	integer_t               logical_cpu_max;        /* max number of physical CPUs possible */
	uint64_t                max_mem;                /* actual size of physical memory */
};

#pragma pack(pop)

typedef struct host_basic_info  host_basic_info_data_t;
typedef struct host_basic_info  *host_basic_info_t;
#define HOST_BASIC_INFO_COUNT ((mach_msg_type_number_t) \
	        (sizeof(host_basic_info_data_t)/sizeof(integer_t)))

struct host_sched_info {
	integer_t       min_timeout;    /* minimum timeout in milliseconds */
	integer_t       min_quantum;    /* minimum quantum in milliseconds */
};

typedef struct host_sched_info  host_sched_info_data_t;
typedef struct host_sched_info  *host_sched_info_t;
#define HOST_SCHED_INFO_COUNT ((mach_msg_type_number_t) \
	        (sizeof(host_sched_info_data_t)/sizeof(integer_t)))

struct kernel_resource_sizes {
	natural_t       task;
	natural_t       thread;
	natural_t       port;
	natural_t       memory_region;
	natural_t       memory_object;
};

typedef struct kernel_resource_sizes    kernel_resource_sizes_data_t;
typedef struct kernel_resource_sizes    *kernel_resource_sizes_t;
#define HOST_RESOURCE_SIZES_COUNT ((mach_msg_type_number_t) \
	        (sizeof(kernel_resource_sizes_data_t)/sizeof(integer_t)))

struct host_priority_info {
	integer_t       kernel_priority;
	integer_t       system_priority;
	integer_t       server_priority;
	integer_t       user_priority;
	integer_t       depress_priority;
	integer_t       idle_priority;
	integer_t       minimum_priority;
	integer_t       maximum_priority;
};

typedef struct host_priority_info       host_priority_info_data_t;
typedef struct host_priority_info       *host_priority_info_t;
#define HOST_PRIORITY_INFO_COUNT ((mach_msg_type_number_t) \
	        (sizeof(host_priority_info_data_t)/sizeof(integer_t)))

/* host_statistics() */
#define HOST_LOAD_INFO          1       /* System loading stats */
#define HOST_VM_INFO            2       /* Virtual memory stats */
#define HOST_CPU_LOAD_INFO      3       /* CPU load stats */

/* host_statistics64() */
#define HOST_VM_INFO64          4       /* 64-bit virtual memory stats */
#define HOST_EXTMOD_INFO64      5       /* External modification stats */
#define HOST_EXPIRED_TASK_INFO  6       /* Statistics for expired tasks */


struct host_load_info {
	integer_t       avenrun[3];     /* scaled by LOAD_SCALE */
	integer_t       mach_factor[3]; /* scaled by LOAD_SCALE */
};

typedef struct host_load_info   host_load_info_data_t;
typedef struct host_load_info   *host_load_info_t;
#define HOST_LOAD_INFO_COUNT ((mach_msg_type_number_t) \
	        (sizeof(host_load_info_data_t)/sizeof(integer_t)))

typedef struct vm_purgeable_info        host_purgable_info_data_t;
typedef struct vm_purgeable_info        *host_purgable_info_t;
#define HOST_VM_PURGABLE_COUNT ((mach_msg_type_number_t) \
	        (sizeof(host_purgable_info_data_t)/sizeof(integer_t)))

/* in <mach/vm_statistics.h> */
/* vm_statistics64 */
#define HOST_VM_INFO64_COUNT ((mach_msg_type_number_t) \
	        (sizeof(vm_statistics64_data_t)/sizeof(integer_t)))

/* size of the latest version of the structure */
#define HOST_VM_INFO64_LATEST_COUNT HOST_VM_INFO64_COUNT
#define HOST_VM_INFO64_REV1_COUNT HOST_VM_INFO64_LATEST_COUNT
/* previous versions: adjust the size according to what was added each time */
#define HOST_VM_INFO64_REV0_COUNT /* added compression and swapper info (14 ints) */ \
	((mach_msg_type_number_t) \
	 (HOST_VM_INFO64_REV1_COUNT - 14))

/* in <mach/vm_statistics.h> */
/* vm_extmod_statistics */
#define HOST_EXTMOD_INFO64_COUNT ((mach_msg_type_number_t) \
	    (sizeof(vm_extmod_statistics_data_t)/sizeof(integer_t)))

/* size of the latest version of the structure */
#define HOST_EXTMOD_INFO64_LATEST_COUNT HOST_EXTMOD_INFO64_COUNT

/* vm_statistics */
#define HOST_VM_INFO_COUNT ((mach_msg_type_number_t) \
	        (sizeof(vm_statistics_data_t)/sizeof(integer_t)))

/* size of the latest version of the structure */
#define HOST_VM_INFO_LATEST_COUNT HOST_VM_INFO_COUNT
#define HOST_VM_INFO_REV2_COUNT HOST_VM_INFO_LATEST_COUNT
/* previous versions: adjust the size according to what was added each time */
#define HOST_VM_INFO_REV1_COUNT /* added "speculative_count" (1 int) */ \
	((mach_msg_type_number_t) \
	 (HOST_VM_INFO_REV2_COUNT - 1))
#define HOST_VM_INFO_REV0_COUNT /* added "purgable" info (2 ints) */    \
	((mach_msg_type_number_t) \
	 (HOST_VM_INFO_REV1_COUNT - 2))

struct host_cpu_load_info {             /* number of ticks while running... */
	natural_t       cpu_ticks[CPU_STATE_MAX]; /* ... in the given mode */
};

typedef struct host_cpu_load_info       host_cpu_load_info_data_t;
typedef struct host_cpu_load_info       *host_cpu_load_info_t;
#define HOST_CPU_LOAD_INFO_COUNT ((mach_msg_type_number_t) \
	        (sizeof (host_cpu_load_info_data_t) / sizeof (integer_t)))

struct host_preferred_user_arch {
	cpu_type_t      cpu_type;       /* Preferred user-space cpu type */
	cpu_subtype_t   cpu_subtype;    /* Preferred user-space cpu subtype */
};

typedef struct host_preferred_user_arch host_preferred_user_arch_data_t;
typedef struct host_preferred_user_arch *host_preferred_user_arch_t;
#define HOST_PREFERRED_USER_ARCH_COUNT ((mach_msg_type_number_t) \
	        (sizeof(host_preferred_user_arch_data_t)/sizeof(integer_t)))




#endif  /* _MACH_HOST_INFO_H_ */