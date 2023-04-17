/*
 * Copyright (c) 2000-2018 Apple Inc. All rights reserved.
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
 * NOTICE: This file was modified by SPARTA, Inc. in 2005 to introduce
 * support for mandatory and extensible security protections.  This notice
 * is included in support of clause 2.2 (b) of the Apple Public License,
 * Version 2.0.
 */
/*
 *	File:	mach/mach_types.h
 *	Author:	Avadis Tevanian, Jr., Michael Wayne Young
 *	Date:	1986
 *
 *	Mach external interface definitions.
 *
 */

#ifndef _MACH_MACH_TYPES_H_
#define _MACH_MACH_TYPES_H_

#include <stdint.h>

#include <sys/cdefs.h>

#include <mach/host_info.h>
#include <mach/host_notify.h>
#include <mach/host_special_ports.h>
#include <mach/machine.h>
#include <mach/machine/vm_types.h>
#include <mach/memory_object_types.h>
#include <mach/message.h>
#include <mach/exception_types.h>
#include <mach/port.h>
#include <mach/mach_voucher_types.h>
#include <mach/processor_info.h>
#include <mach/task_info.h>
#include <mach/task_inspect.h>
#include <mach/task_policy.h>
#include <mach/task_special_ports.h>
#include <mach/thread_info.h>
#include <mach/thread_policy.h>
#include <mach/thread_special_ports.h>
#include <mach/thread_status.h>
#include <mach/time_value.h>
#include <mach/clock_types.h>
#include <mach/vm_attributes.h>
#include <mach/vm_inherit.h>
#include <mach/vm_purgable.h>
#include <mach/vm_behavior.h>
#include <mach/vm_prot.h>
#include <mach/vm_statistics.h>
#include <mach/vm_sync.h>
#include <mach/vm_types.h>
#include <mach/vm_region.h>
#include <mach/kmod.h>
#include <mach/dyld_kernel.h>


/*
 * If we are not in the kernel, then these will all be represented by
 * ports at user-space.
 */
typedef mach_port_t             task_t;
typedef mach_port_t             task_name_t;
typedef mach_port_t             task_policy_set_t;
typedef mach_port_t             task_policy_get_t;
typedef mach_port_t             task_inspect_t;
typedef mach_port_t             task_read_t;
typedef mach_port_t             task_suspension_token_t;
typedef mach_port_t             thread_t;
typedef mach_port_t             thread_act_t;
typedef mach_port_t             thread_inspect_t;
typedef mach_port_t             thread_read_t;
typedef mach_port_t             ipc_space_t;
typedef mach_port_t             ipc_space_read_t;
typedef mach_port_t             ipc_space_inspect_t;
typedef mach_port_t             coalition_t;
typedef mach_port_t             host_t;
typedef mach_port_t             host_priv_t;
typedef mach_port_t             host_security_t;
typedef mach_port_t             processor_t;
typedef mach_port_t             processor_set_t;
typedef mach_port_t             processor_set_control_t;
typedef mach_port_t             semaphore_t;
typedef mach_port_t             lock_set_t;
typedef mach_port_t             ledger_t;
typedef mach_port_t             alarm_t;
typedef mach_port_t             clock_serv_t;
typedef mach_port_t             clock_ctrl_t;
typedef mach_port_t             arcade_register_t;
typedef mach_port_t             ipc_eventlink_t;
typedef mach_port_t             eventlink_port_pair_t[2];
typedef mach_port_t             task_id_token_t;
typedef mach_port_t             kcdata_object_t;


/*
 * These aren't really unique types.  They are just called
 * out as unique types at one point in history.  So we list
 * them here for compatibility.
 */
typedef processor_set_t         processor_set_name_t;

/*
 * These types are just hard-coded as ports
 */
typedef mach_port_t             clock_reply_t;
typedef mach_port_t             bootstrap_t;
typedef mach_port_t             mem_entry_name_port_t;
typedef mach_port_t             exception_handler_t;
typedef exception_handler_t     *exception_handler_array_t;
typedef mach_port_t             vm_task_entry_t;
typedef mach_port_t             io_main_t;
typedef mach_port_t             UNDServerRef;
typedef mach_port_t             mach_eventlink_t;

typedef ipc_info_port_t         exception_handler_info_t;

/*
 * Mig doesn't translate the components of an array.
 * For example, Mig won't use the thread_t translations
 * to translate a thread_array_t argument.  So, these definitions
 * are not completely accurate at the moment for other kernel
 * components.
 */
typedef task_t                  *task_array_t;
typedef thread_t                *thread_array_t;
typedef processor_set_t         *processor_set_array_t;
typedef processor_set_t         *processor_set_name_array_t;
typedef processor_t             *processor_array_t;
typedef thread_act_t            *thread_act_array_t;
typedef ledger_t                *ledger_array_t;

/*
 * However the real mach_types got declared, we also have to declare
 * types with "port" in the name for compatability with the way OSF
 * had declared the user interfaces at one point.  Someday these should
 * go away.
 */
typedef task_t                  task_port_t;
typedef task_array_t            task_port_array_t;
typedef thread_t                thread_port_t;
typedef thread_array_t          thread_port_array_t;
typedef ipc_space_t             ipc_space_port_t;
typedef host_t                  host_name_t;
typedef host_t                  host_name_port_t;
typedef processor_set_t         processor_set_port_t;
typedef processor_set_t         processor_set_name_port_t;
typedef processor_set_array_t   processor_set_name_port_array_t;
typedef processor_set_t         processor_set_control_port_t;
typedef processor_t             processor_port_t;
typedef processor_array_t       processor_port_array_t;
typedef thread_act_t            thread_act_port_t;
typedef thread_act_array_t      thread_act_port_array_t;
typedef semaphore_t             semaphore_port_t;
typedef lock_set_t              lock_set_port_t;
typedef ledger_t                ledger_port_t;
typedef ledger_array_t          ledger_port_array_t;
typedef alarm_t                 alarm_port_t;
typedef clock_serv_t            clock_serv_port_t;
typedef clock_ctrl_t            clock_ctrl_port_t;
typedef exception_handler_t     exception_port_t;
typedef exception_handler_array_t exception_port_arrary_t;
typedef char vfs_path_t[4096];
/*
 * 8K, c.f. FSGETPATH_MAXBUFLEN in bsd/vfs/vfs_syscalls.c.
 * These types should NEVER be allocated on the stack.
 */
typedef char nspace_path_t[8192];
typedef char nspace_name_t[8192];

#define TASK_NULL               ((task_t) 0)
#define TASK_NAME_NULL          ((task_name_t) 0)
#define TASK_INSPECT_NULL       ((task_inspect_t) 0)
#define TASK_READ_NULL          ((task_read_t) 0)
#define THREAD_NULL             ((thread_t) 0)
#define THREAD_INSPECT_NULL     ((thread_inspect_t) 0)
#define THREAD_READ_NULL        ((thread_read_t) 0)
#define TID_NULL                ((uint64_t) 0)
#define THR_ACT_NULL            ((thread_act_t) 0)
#define IPC_SPACE_NULL          ((ipc_space_t) 0)
#define IPC_SPACE_READ_NULL     ((ipc_space_read_t) 0)
#define IPC_SPACE_INSPECT_NULL  ((ipc_space_inspect_t) 0)
#define COALITION_NULL          ((coalition_t) 0)
#define HOST_NULL               ((host_t) 0)
#define HOST_PRIV_NULL          ((host_priv_t) 0)
#define HOST_SECURITY_NULL      ((host_security_t) 0)
#define PROCESSOR_SET_NULL      ((processor_set_t) 0)
#define PROCESSOR_NULL          ((processor_t) 0)
#define SEMAPHORE_NULL          ((semaphore_t) 0)
#define LOCK_SET_NULL           ((lock_set_t) 0)
#define LEDGER_NULL             ((ledger_t) 0)
#define ALARM_NULL              ((alarm_t) 0)
#define CLOCK_NULL              ((clock_t) 0)
#define UND_SERVER_NULL         ((UNDServerRef) 0)
#define ARCADE_REG_NULL         ((arcade_register_t) 0)
#define MACH_EVENTLINK_NULL     ((mach_eventlink_t) 0)
#define IPC_EVENTLINK_NULL      ((ipc_eventlink_t) 0)
#define TASK_ID_TOKEN_NULL      ((task_id_token_t) 0)
#define KCDATA_OBJECT_NULL      ((kcdata_object_t) 0)

/* capability strictly _DECREASING_.
 * not ordered the other way around because we want TASK_FLAVOR_CONTROL
 * to be closest to the itk_lock. see task.h.
 */
typedef unsigned int            mach_task_flavor_t;
#define TASK_FLAVOR_CONTROL     0    /* a task_t */
#define TASK_FLAVOR_READ        1    /* a task_read_t */
#define TASK_FLAVOR_INSPECT     2    /* a task_inspect_t */
#define TASK_FLAVOR_NAME        3    /* a task_name_t */

#define TASK_FLAVOR_MAX         TASK_FLAVOR_NAME

/* capability strictly _DECREASING_ */
typedef unsigned int            mach_thread_flavor_t;
#define THREAD_FLAVOR_CONTROL   0    /* a thread_t */
#define THREAD_FLAVOR_READ      1    /* a thread_read_t */
#define THREAD_FLAVOR_INSPECT   2    /* a thread_inspect_t */

#define THREAD_FLAVOR_MAX       THREAD_FLAVOR_INSPECT

/* DEPRECATED */
typedef natural_t               ledger_item_t;
#define LEDGER_ITEM_INFINITY    ((ledger_item_t) (~0))

typedef int64_t                 ledger_amount_t;
#define LEDGER_LIMIT_INFINITY   ((ledger_amount_t)((1ULL << 63) - 1))

typedef mach_vm_offset_t        *emulation_vector_t;
typedef char                    *user_subsystem_t;

typedef char                    *labelstr_t;
/*
 *	Backwards compatibility, for those programs written
 *	before mach/{std,mach}_types.{defs,h} were set up.
 */
#include <mach/std_types.h>

#endif  /* _MACH_MACH_TYPES_H_ */