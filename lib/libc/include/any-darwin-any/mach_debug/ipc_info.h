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
 * Copyright (c) 1991,1990 Carnegie Mellon University
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
 *	File:	mach_debug/ipc_info.h
 *	Author:	Rich Draves
 *	Date:	March, 1990
 *
 *	Definitions for the IPC debugging interface.
 */

#ifndef _MACH_DEBUG_IPC_INFO_H_
#define _MACH_DEBUG_IPC_INFO_H_

#include <mach/boolean.h>
#include <mach/port.h>
#include <mach/machine/vm_types.h>

/*!
 * @brief
 * Type for mach_port_kobject_description() only.
 *
 * @discussion
 * This type preserved the `IOT_*` values that @c ipc_kobject_type_t used
 * to carry, whose ABI of this type was known to debugging tools of userspace,
 * by copying XNU's source.
 *
 * This provides a guaranteed stable interface now (however no guarantee
 * is made that values are still in use).
 *
 * Values should never be removed to that list, merely abandonned with
 * a comment.
 */
__enum_decl(ipc_info_object_type_t, natural_t, {
	IPC_OTYPE_NONE                  = 0,
	IPC_OTYPE_THREAD_CONTROL        = 1,
	IPC_OTYPE_TASK_CONTROL          = 2,
	IPC_OTYPE_HOST                  = 3,
	IPC_OTYPE_HOST_PRIV             = 4,
	IPC_OTYPE_PROCESSOR             = 5,
	IPC_OTYPE_PROCESSOR_SET         = 6,
	IPC_OTYPE_PROCESSOR_SET_NAME    = 7,
	IPC_OTYPE_TIMER                 = 8,
	IPC_OTYPE_PORT_SUBST_ONCE       = 9,  /* obsolete: no instances */
	IPC_OTYPE_MIG                   = 10, /* obsolete: no instances */
	IPC_OTYPE_MEMORY_OBJECT         = 11, /* no port instances      */
	IPC_OTYPE_XMM_PAGER             = 12, /* obsolete: no instances */
	IPC_OTYPE_XMM_KERNEL            = 13, /* obsolete: no instances */
	IPC_OTYPE_XMM_REPLY             = 14, /* obsolete: no instances */
	IPC_OTYPE_UND_REPLY             = 15,
	IPC_OTYPE_HOST_NOTIFY           = 16, /* obsolete: no instances */
	IPC_OTYPE_HOST_SECURITY         = 17, /* obsolete: no instances */
	IPC_OTYPE_LEDGER                = 18, /* obsolete: no instances */
	IPC_OTYPE_MAIN_DEVICE           = 19,
	IPC_OTYPE_TASK_NAME             = 20,
	IPC_OTYPE_SUBSYSTEM             = 21, /* obsolete: no instances */
	IPC_OTYPE_IO_DONE_QUEUE         = 22, /* obsolete: no instances */
	IPC_OTYPE_SEMAPHORE             = 23,
	IPC_OTYPE_LOCK_SET              = 24, /* obsolete: no instances */
	IPC_OTYPE_CLOCK                 = 25,
	IPC_OTYPE_CLOCK_CTRL            = 26, /* obsolete: no instances */
	IPC_OTYPE_IOKIT_IDENT           = 27,
	IPC_OTYPE_NAMED_ENTRY           = 28,
	IPC_OTYPE_IOKIT_CONNECT         = 29,
	IPC_OTYPE_IOKIT_OBJECT          = 30,
	IPC_OTYPE_UPL                   = 31, /* obsolete: no instances */
	IPC_OTYPE_MEM_OBJ_CONTROL       = 32, /* obsolete: no instances */
	IPC_OTYPE_AU_SESSIONPORT        = 33,
	IPC_OTYPE_FILEPORT              = 34,
	IPC_OTYPE_LABELH                = 35, /* obsolete: no instances */
	IPC_OTYPE_TASK_RESUME           = 36,
	IPC_OTYPE_VOUCHER               = 37,
	IPC_OTYPE_VOUCHER_ATTR_CONTROL  = 38, /* obsolete: no instances */
	IPC_OTYPE_WORK_INTERVAL         = 39,
	IPC_OTYPE_UX_HANDLER            = 40,
	IPC_OTYPE_UEXT_OBJECT           = 41,
	IPC_OTYPE_ARCADE_REG            = 42,
	IPC_OTYPE_EVENTLINK             = 43,
	IPC_OTYPE_TASK_INSPECT          = 44,
	IPC_OTYPE_TASK_READ             = 45,
	IPC_OTYPE_THREAD_INSPECT        = 46,
	IPC_OTYPE_THREAD_READ           = 47,
	IPC_OTYPE_SUID_CRED             = 48, /* obsolete: no instances */
	IPC_OTYPE_HYPERVISOR            = 49,
	IPC_OTYPE_TASK_ID_TOKEN         = 50,
	IPC_OTYPE_TASK_FATAL            = 51,
	IPC_OTYPE_KCDATA                = 52,
	IPC_OTYPE_EXCLAVES_RESOURCE     = 53,

	/* catchall */
	IPC_OTYPE_UNKNOWN               = ~0u,
});

/*
 *	Remember to update the mig type definitions
 *	in mach_debug_types.defs when adding/removing fields.
 */

typedef struct ipc_info_space {
	natural_t iis_genno_mask;       /* generation number mask */
	natural_t iis_table_size;       /* size of table */
	natural_t iis_table_next;       /* next possible size of table (UNUSED) */
	natural_t iis_tree_size;        /* size of tree (UNUSED) */
	natural_t iis_tree_small;       /* # of small entries in tree (UNUSED) */
	natural_t iis_tree_hash;        /* # of hashed entries in tree (UNUSED) */
} ipc_info_space_t;

typedef struct ipc_info_space_basic {
	natural_t iisb_genno_mask;      /* generation number mask */
	natural_t iisb_table_size;      /* size of table */
	natural_t iisb_table_next;      /* next possible size of table (UNUSED) */
	natural_t iisb_table_inuse;     /* number of entries in use */
	natural_t iisb_reserved[2];     /* future expansion */
} ipc_info_space_basic_t;

typedef struct ipc_info_name {
	mach_port_name_t iin_name;              /* port name, including gen number */
/*boolean_t*/ integer_t iin_collision;   /* collision at this entry? */
	mach_port_type_t iin_type;      /* straight port type */
	mach_port_urefs_t iin_urefs;    /* user-references */
	natural_t iin_object;           /* object pointer/identifier */
	natural_t iin_next;             /* marequest/next in free list */
	natural_t iin_hash;             /* hash index */
} ipc_info_name_t;

typedef ipc_info_name_t *ipc_info_name_array_t;

/* UNUSED */
typedef struct ipc_info_tree_name {
	ipc_info_name_t iitn_name;
	mach_port_name_t iitn_lchild;   /* name of left child */
	mach_port_name_t iitn_rchild;   /* name of right child */
} ipc_info_tree_name_t;

typedef ipc_info_tree_name_t *ipc_info_tree_name_array_t;

typedef struct ipc_info_port {
	natural_t iip_port_object;      /* port object identifier */
	natural_t iip_receiver_object;  /* receiver task identifier (if any) */
} ipc_info_port_t;

typedef ipc_info_port_t *exception_handler_info_array_t;

#endif  /* _MACH_DEBUG_IPC_INFO_H_ */
