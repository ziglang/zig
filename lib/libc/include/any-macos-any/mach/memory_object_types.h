/*
 * Copyright (c) 2000-2016 Apple Computer, Inc. All rights reserved.
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
/*
 *	File:	memory_object.h
 *	Author:	Michael Wayne Young
 *
 *	External memory management interface definition.
 */

#ifndef _MACH_MEMORY_OBJECT_TYPES_H_
#define _MACH_MEMORY_OBJECT_TYPES_H_

/*
 *	User-visible types used in the external memory
 *	management interface:
 */

#include <mach/port.h>
#include <mach/message.h>
#include <mach/vm_prot.h>
#include <mach/vm_sync.h>
#include <mach/vm_types.h>
#include <mach/machine/vm_types.h>

#include <sys/cdefs.h>

#define VM_64_BIT_DATA_OBJECTS

typedef unsigned long long      memory_object_offset_t;
typedef unsigned long long      memory_object_size_t;
typedef natural_t               memory_object_cluster_size_t;
typedef natural_t *             memory_object_fault_info_t;

typedef unsigned long long      vm_object_id_t;


/*
 * Temporary until real EMMI version gets re-implemented
 */


typedef mach_port_t     memory_object_t;
typedef mach_port_t     memory_object_control_t;


typedef memory_object_t *memory_object_array_t;
/* A memory object ... */
/*  Used by the kernel to retrieve */
/*  or store data */

typedef mach_port_t     memory_object_name_t;
/* Used to describe the memory ... */
/*  object in vm_regions() calls */

typedef mach_port_t     memory_object_default_t;
/* Registered with the host ... */
/*  for creating new internal objects */

#define MEMORY_OBJECT_NULL              ((memory_object_t) 0)
#define MEMORY_OBJECT_CONTROL_NULL      ((memory_object_control_t) 0)
#define MEMORY_OBJECT_NAME_NULL         ((memory_object_name_t) 0)
#define MEMORY_OBJECT_DEFAULT_NULL      ((memory_object_default_t) 0)


typedef int             memory_object_copy_strategy_t;
/* How memory manager handles copy: */
#define         MEMORY_OBJECT_COPY_NONE         0
/* ... No special support */
#define         MEMORY_OBJECT_COPY_CALL         1
/* ... Make call on memory manager */
#define         MEMORY_OBJECT_COPY_DELAY        2
/* ... Memory manager doesn't
 *     change data externally.
 */
#define         MEMORY_OBJECT_COPY_TEMPORARY    3
/* ... Memory manager doesn't
 *     change data externally, and
 *     doesn't need to see changes.
 */
#define         MEMORY_OBJECT_COPY_SYMMETRIC    4
/* ... Memory manager doesn't
 *     change data externally,
 *     doesn't need to see changes,
 *     and object will not be
 *     multiply mapped.
 *
 *     XXX
 *     Not yet safe for non-kernel use.
 */

#define         MEMORY_OBJECT_COPY_INVALID      5
/* ...	An invalid copy strategy,
 *	for external objects which
 *	have not been initialized.
 *	Allows copy_strategy to be
 *	examined without also
 *	examining pager_ready and
 *	internal.
 */

typedef int             memory_object_return_t;
/* Which pages to return to manager
 *  this time (lock_request) */
#define         MEMORY_OBJECT_RETURN_NONE       0
/* ... don't return any. */
#define         MEMORY_OBJECT_RETURN_DIRTY      1
/* ... only dirty pages. */
#define         MEMORY_OBJECT_RETURN_ALL        2
/* ... dirty and precious pages. */
#define         MEMORY_OBJECT_RETURN_ANYTHING   3
/* ... any resident page. */

/*
 *	Data lock request flags
 */

#define         MEMORY_OBJECT_DATA_FLUSH        0x1
#define         MEMORY_OBJECT_DATA_NO_CHANGE    0x2
#define         MEMORY_OBJECT_DATA_PURGE        0x4
#define         MEMORY_OBJECT_COPY_SYNC         0x8
#define         MEMORY_OBJECT_DATA_SYNC         0x10
#define         MEMORY_OBJECT_IO_SYNC           0x20
#define         MEMORY_OBJECT_DATA_FLUSH_ALL    0x40

/*
 *	Types for the memory object flavor interfaces
 */

#define MEMORY_OBJECT_INFO_MAX      (1024)
typedef int     *memory_object_info_t;
typedef int      memory_object_flavor_t;
typedef int      memory_object_info_data_t[MEMORY_OBJECT_INFO_MAX];


#define MEMORY_OBJECT_PERFORMANCE_INFO  11
#define MEMORY_OBJECT_ATTRIBUTE_INFO    14
#define MEMORY_OBJECT_BEHAVIOR_INFO     15


struct memory_object_perf_info {
	memory_object_cluster_size_t    cluster_size;
	boolean_t                       may_cache;
};

struct memory_object_attr_info {
	memory_object_copy_strategy_t   copy_strategy;
	memory_object_cluster_size_t    cluster_size;
	boolean_t                       may_cache_object;
	boolean_t                       temporary;
};

struct memory_object_behave_info {
	memory_object_copy_strategy_t   copy_strategy;
	boolean_t                       temporary;
	boolean_t                       invalidate;
	boolean_t                       silent_overwrite;
	boolean_t                       advisory_pageout;
};


typedef struct memory_object_behave_info *memory_object_behave_info_t;
typedef struct memory_object_behave_info memory_object_behave_info_data_t;

typedef struct memory_object_perf_info  *memory_object_perf_info_t;
typedef struct memory_object_perf_info  memory_object_perf_info_data_t;

typedef struct memory_object_attr_info  *memory_object_attr_info_t;
typedef struct memory_object_attr_info  memory_object_attr_info_data_t;

#define MEMORY_OBJECT_BEHAVE_INFO_COUNT ((mach_msg_type_number_t)       \
	        (sizeof(memory_object_behave_info_data_t)/sizeof(int)))
#define MEMORY_OBJECT_PERF_INFO_COUNT   ((mach_msg_type_number_t)       \
	        (sizeof(memory_object_perf_info_data_t)/sizeof(int)))
#define MEMORY_OBJECT_ATTR_INFO_COUNT   ((mach_msg_type_number_t)       \
	        (sizeof(memory_object_attr_info_data_t)/sizeof(int)))

#define invalid_memory_object_flavor(f)                                 \
	(f != MEMORY_OBJECT_ATTRIBUTE_INFO &&                           \
	 f != MEMORY_OBJECT_PERFORMANCE_INFO &&                         \
	 f != OLD_MEMORY_OBJECT_BEHAVIOR_INFO &&                        \
	 f != MEMORY_OBJECT_BEHAVIOR_INFO &&                            \
	 f != OLD_MEMORY_OBJECT_ATTRIBUTE_INFO)


/*
 * Used to support options on memory_object_release_name call
 */
#define MEMORY_OBJECT_TERMINATE_IDLE    0x1
#define MEMORY_OBJECT_RESPECT_CACHE     0x2
#define MEMORY_OBJECT_RELEASE_NO_OP     0x4


/* named entry processor mapping options */
/* enumerated */
#define MAP_MEM_NOOP                      0
#define MAP_MEM_COPYBACK                  1
#define MAP_MEM_IO                        2
#define MAP_MEM_WTHRU                     3
#define MAP_MEM_WCOMB                     4       /* Write combining mode */
                                                  /* aka store gather     */
#define MAP_MEM_INNERWBACK                5
#define MAP_MEM_POSTED                    6
#define MAP_MEM_RT                        7
#define MAP_MEM_POSTED_REORDERED          8
#define MAP_MEM_POSTED_COMBINED_REORDERED 9

#define GET_MAP_MEM(flags)      \
	((((unsigned int)(flags)) >> 24) & 0xFF)

#define SET_MAP_MEM(caching, flags)     \
	((flags) = ((((unsigned int)(caching)) << 24) \
	                & 0xFF000000) | ((flags) & 0xFFFFFF));

/* leave room for vm_prot bits (0xFF ?) */
#define MAP_MEM_LEDGER_TAGGED        0x002000 /* object owned by a specific task and ledger */
#define MAP_MEM_PURGABLE_KERNEL_ONLY 0x004000 /* volatility controlled by kernel */
#define MAP_MEM_GRAB_SECLUDED   0x008000 /* can grab secluded pages */
#define MAP_MEM_ONLY            0x010000 /* change processor caching  */
#define MAP_MEM_NAMED_CREATE    0x020000 /* create extant object      */
#define MAP_MEM_PURGABLE        0x040000 /* create a purgable VM object */
#define MAP_MEM_NAMED_REUSE     0x080000 /* reuse provided entry if identical */
#define MAP_MEM_USE_DATA_ADDR   0x100000 /* preserve address of data, rather than base of page */
#define MAP_MEM_VM_COPY         0x200000 /* make a copy of a VM range */
#define MAP_MEM_VM_SHARE        0x400000 /* extract a VM range for remap */
#define MAP_MEM_4K_DATA_ADDR    0x800000 /* preserve 4K aligned address of data */

#define MAP_MEM_FLAGS_MASK 0x00FFFF00
#define MAP_MEM_FLAGS_USER (                               \
	MAP_MEM_PURGABLE_KERNEL_ONLY |                     \
	MAP_MEM_GRAB_SECLUDED |                            \
	MAP_MEM_ONLY |                                     \
	MAP_MEM_NAMED_CREATE |                             \
	MAP_MEM_PURGABLE |                                 \
	MAP_MEM_NAMED_REUSE |                              \
	MAP_MEM_USE_DATA_ADDR |                            \
	MAP_MEM_VM_COPY |                                  \
	MAP_MEM_VM_SHARE |                                 \
	MAP_MEM_LEDGER_TAGGED |                            \
	MAP_MEM_4K_DATA_ADDR)
#define MAP_MEM_FLAGS_ALL (                     \
	MAP_MEM_FLAGS_USER)


#endif  /* _MACH_MEMORY_OBJECT_TYPES_H_ */