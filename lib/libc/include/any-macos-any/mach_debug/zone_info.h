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
 * Copyright (c) 1991,1990,1989 Carnegie Mellon University
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

#ifndef _MACH_DEBUG_ZONE_INFO_H_
#define _MACH_DEBUG_ZONE_INFO_H_

#include <mach/boolean.h>
#include <mach/machine/vm_types.h>

/*
 *	Legacy definitions for host_zone_info().  This interface, and
 *	these definitions have been deprecated in favor of the new
 *	mach_zone_info() inteface and types below.
 */

#define ZONE_NAME_MAX_LEN               80

typedef struct zone_name {
	char            zn_name[ZONE_NAME_MAX_LEN];
} zone_name_t;

typedef zone_name_t *zone_name_array_t;


typedef struct zone_info {
	integer_t       zi_count;       /* Number of elements used now */
	vm_size_t       zi_cur_size;    /* current memory utilization */
	vm_size_t       zi_max_size;    /* how large can this zone grow */
	vm_size_t       zi_elem_size;   /* size of an element */
	vm_size_t       zi_alloc_size;  /* size used for more memory */
	integer_t       zi_pageable;    /* zone pageable? */
	integer_t       zi_sleepable;   /* sleep if empty? */
	integer_t       zi_exhaustible; /* merely return if empty? */
	integer_t       zi_collectable; /* garbage collect elements? */
} zone_info_t;

typedef zone_info_t *zone_info_array_t;


/*
 *	Remember to update the mig type definitions
 *	in mach_debug_types.defs when adding/removing fields.
 */

#define MACH_ZONE_NAME_MAX_LEN          80

typedef struct mach_zone_name {
	char            mzn_name[ZONE_NAME_MAX_LEN];
} mach_zone_name_t;

typedef mach_zone_name_t *mach_zone_name_array_t;

typedef struct mach_zone_info_data {
	uint64_t        mzi_count;      /* count of elements in use */
	uint64_t        mzi_cur_size;   /* current memory utilization */
	uint64_t        mzi_max_size;   /* how large can this zone grow */
	uint64_t        mzi_elem_size;  /* size of an element */
	uint64_t        mzi_alloc_size; /* size used for more memory */
	uint64_t        mzi_sum_size;   /* sum of all allocs (life of zone) */
	uint64_t        mzi_exhaustible;        /* merely return if empty? */
	uint64_t        mzi_collectable;        /* garbage collect elements? and how much? */
} mach_zone_info_t;

typedef mach_zone_info_t *mach_zone_info_array_t;

/*
 * The lowest bit of mzi_collectable indicates whether or not the zone
 * is collectable by zone_gc(). The higher bits contain the size in bytes
 * that can be collected.
 */
#define GET_MZI_COLLECTABLE_BYTES(val)  ((val) >> 1)
#define GET_MZI_COLLECTABLE_FLAG(val)   ((val) & 1)

#define SET_MZI_COLLECTABLE_BYTES(val, size)    \
	(val) = ((val) & 1) | ((size) << 1)
#define SET_MZI_COLLECTABLE_FLAG(val, flag)             \
	(val) = (flag) ? ((val) | 1) : (val)

typedef struct task_zone_info_data {
	uint64_t        tzi_count;      /* count of elements in use */
	uint64_t        tzi_cur_size;   /* current memory utilization */
	uint64_t        tzi_max_size;   /* how large can this zone grow */
	uint64_t        tzi_elem_size;  /* size of an element */
	uint64_t        tzi_alloc_size; /* size used for more memory */
	uint64_t        tzi_sum_size;   /* sum of all allocs (life of zone) */
	uint64_t        tzi_exhaustible;        /* merely return if empty? */
	uint64_t        tzi_collectable;        /* garbage collect elements? */
	uint64_t        tzi_caller_acct;        /* charged to caller (or kernel) */
	uint64_t        tzi_task_alloc; /* sum of all allocs by this task */
	uint64_t        tzi_task_free;  /* sum of all frees by this task */
} task_zone_info_t;

typedef task_zone_info_t *task_zone_info_array_t;

#define MACH_MEMORY_INFO_NAME_MAX_LEN   80

typedef struct mach_memory_info {
	uint64_t flags;
	uint64_t site;
	uint64_t size;
	uint64_t free;
	uint64_t largest;
	uint64_t collectable_bytes;
	uint64_t mapped;
	uint64_t peak;
	uint16_t tag;
	uint16_t zone;
	uint16_t _resvA[2];
	uint64_t _resv[3];
	char     name[MACH_MEMORY_INFO_NAME_MAX_LEN];
} mach_memory_info_t;

typedef mach_memory_info_t *mach_memory_info_array_t;

/*
 * MAX_ZTRACE_DEPTH configures how deep of a stack trace is taken on each zalloc in the zone of interest.  15
 * levels is usually enough to get past all the layers of code in kalloc and IOKit and see who the actual
 * caller is up above these lower levels.
 *
 * This is used both for the zone leak detector and the zone corruption log. Make sure this isn't greater than
 * BTLOG_MAX_DEPTH defined in btlog.h. Also make sure to update the definition of zone_btrecord_t in
 * mach_debug_types.defs if this changes.
 */

#define MAX_ZTRACE_DEPTH        15

/*
 * Opcodes for the btlog operation field:
 */

#define ZOP_ALLOC       1
#define ZOP_FREE        0

/*
 * Structure used to copy out btlog records to userspace, via the MIG call
 * mach_zone_get_btlog_records().
 */
typedef struct zone_btrecord {
	uint32_t    ref_count;                                  /* no. of active references on the record */
	uint32_t        operation_type;                         /* operation type (alloc/free) */
	uint64_t        bt[MAX_ZTRACE_DEPTH];           /* backtrace */
} zone_btrecord_t;

typedef zone_btrecord_t *zone_btrecord_array_t;

#endif  /* _MACH_DEBUG_ZONE_INFO_H_ */
