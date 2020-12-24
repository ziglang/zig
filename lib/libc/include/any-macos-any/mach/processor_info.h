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

/*
 *	File:	mach/processor_info.h
 *	Author:	David L. Black
 *	Date:	1988
 *
 *	Data structure definitions for processor_info, processor_set_info
 */

#ifndef _MACH_PROCESSOR_INFO_H_
#define _MACH_PROCESSOR_INFO_H_

#include <mach/message.h>
#include <mach/machine.h>
#include <mach/machine/processor_info.h>

/*
 *	Generic information structure to allow for expansion.
 */
typedef integer_t       *processor_info_t;      /* varying array of int. */
typedef integer_t       *processor_info_array_t;  /* varying array of int */

#define PROCESSOR_INFO_MAX      (1024)  /* max array size */
typedef integer_t       processor_info_data_t[PROCESSOR_INFO_MAX];


typedef integer_t       *processor_set_info_t;  /* varying array of int. */

#define PROCESSOR_SET_INFO_MAX  (1024)  /* max array size */
typedef integer_t       processor_set_info_data_t[PROCESSOR_SET_INFO_MAX];

/*
 *	Currently defined information.
 */
typedef int     processor_flavor_t;
#define PROCESSOR_BASIC_INFO    1               /* basic information */
#define PROCESSOR_CPU_LOAD_INFO 2       /* cpu load information */
#define PROCESSOR_PM_REGS_INFO  0x10000001      /* performance monitor register info */
#define PROCESSOR_TEMPERATURE   0x10000002      /* Processor core temperature */

struct processor_basic_info {
	cpu_type_t      cpu_type;       /* type of cpu */
	cpu_subtype_t   cpu_subtype;    /* subtype of cpu */
	boolean_t       running;        /* is processor running */
	int             slot_num;       /* slot number */
	boolean_t       is_master;      /* is this the master processor */
};

typedef struct processor_basic_info     processor_basic_info_data_t;
typedef struct processor_basic_info     *processor_basic_info_t;
#define PROCESSOR_BASIC_INFO_COUNT      ((mach_msg_type_number_t) \
	        (sizeof(processor_basic_info_data_t)/sizeof(natural_t)))

struct processor_cpu_load_info {             /* number of ticks while running... */
	unsigned int    cpu_ticks[CPU_STATE_MAX]; /* ... in the given mode */
};

typedef struct processor_cpu_load_info  processor_cpu_load_info_data_t;
typedef struct processor_cpu_load_info  *processor_cpu_load_info_t;
#define PROCESSOR_CPU_LOAD_INFO_COUNT   ((mach_msg_type_number_t) \
	        (sizeof(processor_cpu_load_info_data_t)/sizeof(natural_t)))

/*
 *	Scaling factor for load_average, mach_factor.
 */
#define LOAD_SCALE      1000

typedef int     processor_set_flavor_t;
#define PROCESSOR_SET_BASIC_INFO        5       /* basic information */

struct processor_set_basic_info {
	int             processor_count;        /* How many processors */
	int             default_policy;         /* When others not enabled */
};

typedef struct processor_set_basic_info processor_set_basic_info_data_t;
typedef struct processor_set_basic_info *processor_set_basic_info_t;
#define PROCESSOR_SET_BASIC_INFO_COUNT  ((mach_msg_type_number_t) \
	        (sizeof(processor_set_basic_info_data_t)/sizeof(natural_t)))

#define PROCESSOR_SET_LOAD_INFO         4       /* scheduling statistics */

struct processor_set_load_info {
	int             task_count;             /* How many tasks */
	int             thread_count;           /* How many threads */
	integer_t       load_average;           /* Scaled */
	integer_t       mach_factor;            /* Scaled */
};

typedef struct processor_set_load_info processor_set_load_info_data_t;
typedef struct processor_set_load_info *processor_set_load_info_t;
#define PROCESSOR_SET_LOAD_INFO_COUNT   ((mach_msg_type_number_t) \
	        (sizeof(processor_set_load_info_data_t)/sizeof(natural_t)))


#endif  /* _MACH_PROCESSOR_INFO_H_ */