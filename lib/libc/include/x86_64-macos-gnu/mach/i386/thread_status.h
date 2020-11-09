/*
 * Copyright (c) 2000-2020 Apple Computer, Inc. All rights reserved.
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
 *	File:	thread_status.h
 *	Author:	Avadis Tevanian, Jr.
 *	Date:	1985
 *
 *	This file contains the structure definitions for the thread
 *	state as applied to I386 processors.
 */

#ifndef _MACH_I386_THREAD_STATUS_H_
#define _MACH_I386_THREAD_STATUS_H_

#include <mach/machine/_structs.h>
#include <mach/message.h>
#include <mach/i386/fp_reg.h>
#include <mach/i386/thread_state.h>
#include <i386/eflags.h>


/*
 * the i386_xxxx form is kept for legacy purposes since these types
 * are externally known... eventually they should be deprecated.
 * our internal implementation has moved to the following naming convention
 *
 *   x86_xxxx32 names are used to deal with 32 bit states
 *   x86_xxxx64 names are used to deal with 64 bit states
 *   x86_xxxx   names are used to deal with either 32 or 64 bit states
 *	via a self-describing mechanism
 */

/*
 * these are the legacy names which should be deprecated in the future
 * they are externally known which is the only reason we don't just get
 * rid of them
 */
#define i386_THREAD_STATE               1
#define i386_FLOAT_STATE                2
#define i386_EXCEPTION_STATE            3

/*
 * THREAD_STATE_FLAVOR_LIST 0
 *      these are the supported flavors
 */
#define x86_THREAD_STATE32              1
#define x86_FLOAT_STATE32               2
#define x86_EXCEPTION_STATE32           3
#define x86_THREAD_STATE64              4
#define x86_FLOAT_STATE64               5
#define x86_EXCEPTION_STATE64           6
#define x86_THREAD_STATE                7
#define x86_FLOAT_STATE                 8
#define x86_EXCEPTION_STATE             9
#define x86_DEBUG_STATE32               10
#define x86_DEBUG_STATE64               11
#define x86_DEBUG_STATE                 12
#define THREAD_STATE_NONE               13
/* 14 and 15 are used for the internal x86_SAVED_STATE flavours */
/* Arrange for flavors to take sequential values, 32-bit, 64-bit, non-specific */
#define x86_AVX_STATE32                 16
#define x86_AVX_STATE64                 (x86_AVX_STATE32 + 1)
#define x86_AVX_STATE                   (x86_AVX_STATE32 + 2)
#define x86_AVX512_STATE32              19
#define x86_AVX512_STATE64              (x86_AVX512_STATE32 + 1)
#define x86_AVX512_STATE                (x86_AVX512_STATE32 + 2)
#define x86_PAGEIN_STATE                22
#define x86_THREAD_FULL_STATE64         23
#define x86_INSTRUCTION_STATE           24
#define x86_LAST_BRANCH_STATE           25

/*
 * Largest state on this machine:
 * (be sure mach/machine/thread_state.h matches!)
 */
#define THREAD_MACHINE_STATE_MAX        THREAD_STATE_MAX

/*
 * VALID_THREAD_STATE_FLAVOR is a platform specific macro that when passed
 * an exception flavor will return if that is a defined flavor for that
 * platform. The macro must be manually updated to include all of the valid
 * exception flavors as defined above.
 */
#define VALID_THREAD_STATE_FLAVOR(x)            \
	 ((x == x86_THREAD_STATE32)		|| \
	  (x == x86_FLOAT_STATE32)		|| \
	  (x == x86_EXCEPTION_STATE32)		|| \
	  (x == x86_DEBUG_STATE32)		|| \
	  (x == x86_THREAD_STATE64)		|| \
	  (x == x86_THREAD_FULL_STATE64)	|| \
	  (x == x86_FLOAT_STATE64)		|| \
	  (x == x86_EXCEPTION_STATE64)		|| \
	  (x == x86_DEBUG_STATE64)		|| \
	  (x == x86_THREAD_STATE)		|| \
	  (x == x86_FLOAT_STATE)		|| \
	  (x == x86_EXCEPTION_STATE)		|| \
	  (x == x86_DEBUG_STATE)		|| \
	  (x == x86_AVX_STATE32)		|| \
	  (x == x86_AVX_STATE64)		|| \
	  (x == x86_AVX_STATE)			|| \
	  (x == x86_AVX512_STATE32)		|| \
	  (x == x86_AVX512_STATE64)		|| \
	  (x == x86_AVX512_STATE)		|| \
	  (x == x86_PAGEIN_STATE)		|| \
	  (x == x86_INSTRUCTION_STATE)		|| \
	  (x == x86_LAST_BRANCH_STATE)		|| \
	  (x == THREAD_STATE_NONE))

struct x86_state_hdr {
	uint32_t        flavor;
	uint32_t        count;
};
typedef struct x86_state_hdr x86_state_hdr_t;

/*
 * Default segment register values.
 */

#define USER_CODE_SELECTOR      0x0017
#define USER_DATA_SELECTOR      0x001f
#define KERN_CODE_SELECTOR      0x0008
#define KERN_DATA_SELECTOR      0x0010

/*
 * to be deprecated in the future
 */
typedef _STRUCT_X86_THREAD_STATE32 i386_thread_state_t;
#define i386_THREAD_STATE_COUNT ((mach_msg_type_number_t) \
    ( sizeof (i386_thread_state_t) / sizeof (int) ))

typedef _STRUCT_X86_THREAD_STATE32 x86_thread_state32_t;
#define x86_THREAD_STATE32_COUNT        ((mach_msg_type_number_t) \
    ( sizeof (x86_thread_state32_t) / sizeof (int) ))

/*
 * to be deprecated in the future
 */
typedef _STRUCT_X86_FLOAT_STATE32 i386_float_state_t;
#define i386_FLOAT_STATE_COUNT ((mach_msg_type_number_t) \
	        (sizeof(i386_float_state_t)/sizeof(unsigned int)))

typedef _STRUCT_X86_FLOAT_STATE32 x86_float_state32_t;
#define x86_FLOAT_STATE32_COUNT ((mach_msg_type_number_t) \
	        (sizeof(x86_float_state32_t)/sizeof(unsigned int)))

typedef _STRUCT_X86_AVX_STATE32 x86_avx_state32_t;
#define x86_AVX_STATE32_COUNT ((mach_msg_type_number_t) \
	        (sizeof(x86_avx_state32_t)/sizeof(unsigned int)))

typedef _STRUCT_X86_AVX512_STATE32 x86_avx512_state32_t;
#define x86_AVX512_STATE32_COUNT ((mach_msg_type_number_t) \
	        (sizeof(x86_avx512_state32_t)/sizeof(unsigned int)))

/*
 * to be deprecated in the future
 */
typedef _STRUCT_X86_EXCEPTION_STATE32 i386_exception_state_t;
#define i386_EXCEPTION_STATE_COUNT      ((mach_msg_type_number_t) \
    ( sizeof (i386_exception_state_t) / sizeof (int) ))

typedef _STRUCT_X86_EXCEPTION_STATE32 x86_exception_state32_t;
#define x86_EXCEPTION_STATE32_COUNT     ((mach_msg_type_number_t) \
    ( sizeof (x86_exception_state32_t) / sizeof (int) ))

#define I386_EXCEPTION_STATE_COUNT i386_EXCEPTION_STATE_COUNT

typedef _STRUCT_X86_DEBUG_STATE32 x86_debug_state32_t;
#define x86_DEBUG_STATE32_COUNT       ((mach_msg_type_number_t) \
	( sizeof (x86_debug_state32_t) / sizeof (int) ))

#define X86_DEBUG_STATE32_COUNT x86_DEBUG_STATE32_COUNT

typedef _STRUCT_X86_THREAD_STATE64 x86_thread_state64_t;
#define x86_THREAD_STATE64_COUNT        ((mach_msg_type_number_t) \
    ( sizeof (x86_thread_state64_t) / sizeof (int) ))

typedef _STRUCT_X86_THREAD_FULL_STATE64 x86_thread_full_state64_t;
#define x86_THREAD_FULL_STATE64_COUNT   ((mach_msg_type_number_t) \
    ( sizeof (x86_thread_full_state64_t) / sizeof (int) ))

typedef _STRUCT_X86_FLOAT_STATE64 x86_float_state64_t;
#define x86_FLOAT_STATE64_COUNT ((mach_msg_type_number_t) \
	        (sizeof(x86_float_state64_t)/sizeof(unsigned int)))

typedef _STRUCT_X86_AVX_STATE64 x86_avx_state64_t;
#define x86_AVX_STATE64_COUNT ((mach_msg_type_number_t) \
	        (sizeof(x86_avx_state64_t)/sizeof(unsigned int)))

typedef _STRUCT_X86_AVX512_STATE64 x86_avx512_state64_t;
#define x86_AVX512_STATE64_COUNT ((mach_msg_type_number_t) \
	        (sizeof(x86_avx512_state64_t)/sizeof(unsigned int)))

typedef _STRUCT_X86_EXCEPTION_STATE64 x86_exception_state64_t;
#define x86_EXCEPTION_STATE64_COUNT     ((mach_msg_type_number_t) \
    ( sizeof (x86_exception_state64_t) / sizeof (int) ))

#define X86_EXCEPTION_STATE64_COUNT x86_EXCEPTION_STATE64_COUNT

typedef _STRUCT_X86_DEBUG_STATE64 x86_debug_state64_t;
#define x86_DEBUG_STATE64_COUNT ((mach_msg_type_number_t) \
    ( sizeof (x86_debug_state64_t) / sizeof (int) ))

#define X86_DEBUG_STATE64_COUNT x86_DEBUG_STATE64_COUNT

typedef _STRUCT_X86_PAGEIN_STATE x86_pagein_state_t;
#define x86_PAGEIN_STATE_COUNT \
    ((mach_msg_type_number_t)(sizeof(x86_pagein_state_t) / sizeof(int)))

#define X86_PAGEIN_STATE_COUNT x86_PAGEIN_STATE_COUNT

typedef _STRUCT_X86_INSTRUCTION_STATE x86_instruction_state_t;
#define x86_INSTRUCTION_STATE_COUNT \
    ((mach_msg_type_number_t)(sizeof(x86_instruction_state_t) / sizeof(int)))

#define X86_INSTRUCTION_STATE_COUNT x86_INSTRUCTION_STATE_COUNT

typedef _STRUCT_LAST_BRANCH_STATE last_branch_state_t;
#define x86_LAST_BRANCH_STATE_COUNT \
    ((mach_msg_type_number_t)(sizeof(last_branch_state_t) / sizeof(int)))

#define X86_LAST_BRANCH_STATE_COUNT x86_LAST_BRANCH_STATE_COUNT


/*
 * Combined thread, float and exception states
 */
struct x86_thread_state {
	x86_state_hdr_t                 tsh;
	union {
		x86_thread_state32_t        ts32;
		x86_thread_state64_t        ts64;
	} uts;
};

struct x86_float_state {
	x86_state_hdr_t                 fsh;
	union {
		x86_float_state32_t     fs32;
		x86_float_state64_t     fs64;
	} ufs;
};

struct x86_exception_state {
	x86_state_hdr_t                 esh;
	union {
		x86_exception_state32_t es32;
		x86_exception_state64_t es64;
	} ues;
};

struct x86_debug_state {
	x86_state_hdr_t                 dsh;
	union {
		x86_debug_state32_t     ds32;
		x86_debug_state64_t     ds64;
	} uds;
};

struct x86_avx_state {
	x86_state_hdr_t                 ash;
	union {
		x86_avx_state32_t       as32;
		x86_avx_state64_t       as64;
	} ufs;
};

struct x86_avx512_state {
	x86_state_hdr_t                 ash;
	union {
		x86_avx512_state32_t    as32;
		x86_avx512_state64_t    as64;
	} ufs;
};

typedef struct x86_thread_state x86_thread_state_t;
#define x86_THREAD_STATE_COUNT  ((mach_msg_type_number_t) \
	        ( sizeof (x86_thread_state_t) / sizeof (int) ))

typedef struct x86_float_state x86_float_state_t;
#define x86_FLOAT_STATE_COUNT ((mach_msg_type_number_t) \
	        (sizeof(x86_float_state_t)/sizeof(unsigned int)))

typedef struct x86_exception_state x86_exception_state_t;
#define x86_EXCEPTION_STATE_COUNT ((mach_msg_type_number_t) \
	        (sizeof(x86_exception_state_t)/sizeof(unsigned int)))

typedef struct x86_debug_state x86_debug_state_t;
#define x86_DEBUG_STATE_COUNT ((mach_msg_type_number_t) \
	        (sizeof(x86_debug_state_t)/sizeof(unsigned int)))

typedef struct x86_avx_state x86_avx_state_t;
#define x86_AVX_STATE_COUNT ((mach_msg_type_number_t) \
	        (sizeof(x86_avx_state_t)/sizeof(unsigned int)))

typedef struct x86_avx512_state x86_avx512_state_t;
#define x86_AVX512_STATE_COUNT ((mach_msg_type_number_t) \
	        (sizeof(x86_avx512_state_t)/sizeof(unsigned int)))

/*
 * Machine-independent way for servers and Mach's exception mechanism to
 * choose the most efficient state flavor for exception RPC's:
 */
#define MACHINE_THREAD_STATE            x86_THREAD_STATE
#define MACHINE_THREAD_STATE_COUNT      x86_THREAD_STATE_COUNT


#endif  /* _MACH_I386_THREAD_STATUS_H_ */
