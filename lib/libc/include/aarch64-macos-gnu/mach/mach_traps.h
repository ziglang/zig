/*
 * Copyright (c) 2000-2019 Apple Inc. All rights reserved.
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
 *	Definitions of general Mach system traps.
 *
 *	These are the definitions as seen from user-space.
 *	The kernel definitions are in <mach/syscall_sw.h>.
 *	Kernel RPC functions are defined in <mach/mach_interface.h>.
 */

#ifndef _MACH_MACH_TRAPS_H_
#define _MACH_MACH_TRAPS_H_

#include <stdint.h>

#include <mach/std_types.h>
#include <mach/mach_types.h>
#include <mach/kern_return.h>
#include <mach/port.h>
#include <mach/vm_types.h>
#include <mach/clock_types.h>

#include <machine/endian.h>

#include <sys/cdefs.h>

__BEGIN_DECLS



extern kern_return_t clock_sleep_trap(
	mach_port_name_t clock_name,
	sleep_type_t sleep_type,
	int sleep_sec,
	int sleep_nsec,
	mach_timespec_t *wakeup_time);

extern kern_return_t _kernelrpc_mach_vm_allocate_trap(
	mach_port_name_t target,
	mach_vm_offset_t *addr,
	mach_vm_size_t size,
	int flags);

extern kern_return_t _kernelrpc_mach_vm_deallocate_trap(
	mach_port_name_t target,
	mach_vm_address_t address,
	mach_vm_size_t size
	);

extern kern_return_t task_dyld_process_info_notify_get(
	mach_port_name_array_t names_addr,
	natural_t *names_count_addr
	);

extern kern_return_t _kernelrpc_mach_vm_protect_trap(
	mach_port_name_t target,
	mach_vm_address_t address,
	mach_vm_size_t size,
	boolean_t set_maximum,
	vm_prot_t new_protection
	);

extern kern_return_t _kernelrpc_mach_vm_map_trap(
	mach_port_name_t target,
	mach_vm_offset_t *address,
	mach_vm_size_t size,
	mach_vm_offset_t mask,
	int flags,
	vm_prot_t cur_protection
	);

extern kern_return_t _kernelrpc_mach_vm_purgable_control_trap(
	mach_port_name_t target,
	mach_vm_offset_t address,
	vm_purgable_t control,
	int *state);

extern kern_return_t _kernelrpc_mach_port_allocate_trap(
	mach_port_name_t target,
	mach_port_right_t right,
	mach_port_name_t *name
	);

extern kern_return_t _kernelrpc_mach_port_deallocate_trap(
	mach_port_name_t target,
	mach_port_name_t name
	);

extern kern_return_t _kernelrpc_mach_port_mod_refs_trap(
	mach_port_name_t target,
	mach_port_name_t name,
	mach_port_right_t right,
	mach_port_delta_t delta
	);

extern kern_return_t _kernelrpc_mach_port_move_member_trap(
	mach_port_name_t target,
	mach_port_name_t member,
	mach_port_name_t after
	);

extern kern_return_t _kernelrpc_mach_port_insert_right_trap(
	mach_port_name_t target,
	mach_port_name_t name,
	mach_port_name_t poly,
	mach_msg_type_name_t polyPoly
	);

extern kern_return_t _kernelrpc_mach_port_get_attributes_trap(
	mach_port_name_t target,
	mach_port_name_t name,
	mach_port_flavor_t flavor,
	mach_port_info_t port_info_out,
	mach_msg_type_number_t *port_info_outCnt
	);

extern kern_return_t _kernelrpc_mach_port_insert_member_trap(
	mach_port_name_t target,
	mach_port_name_t name,
	mach_port_name_t pset
	);

extern kern_return_t _kernelrpc_mach_port_extract_member_trap(
	mach_port_name_t target,
	mach_port_name_t name,
	mach_port_name_t pset
	);

extern kern_return_t _kernelrpc_mach_port_construct_trap(
	mach_port_name_t target,
	mach_port_options_t *options,
	uint64_t context,
	mach_port_name_t *name
	);

extern kern_return_t _kernelrpc_mach_port_destruct_trap(
	mach_port_name_t target,
	mach_port_name_t name,
	mach_port_delta_t srdelta,
	uint64_t guard
	);

extern kern_return_t _kernelrpc_mach_port_guard_trap(
	mach_port_name_t target,
	mach_port_name_t name,
	uint64_t guard,
	boolean_t strict
	);

extern kern_return_t _kernelrpc_mach_port_unguard_trap(
	mach_port_name_t target,
	mach_port_name_t name,
	uint64_t guard
	);

extern kern_return_t mach_generate_activity_id(
	mach_port_name_t target,
	int count,
	uint64_t *activity_id
	);

extern kern_return_t macx_swapon(
	uint64_t filename,
	int flags,
	int size,
	int priority);

extern kern_return_t macx_swapoff(
	uint64_t filename,
	int flags);

extern kern_return_t macx_triggers(
	int hi_water,
	int low_water,
	int flags,
	mach_port_t alert_port);

extern kern_return_t macx_backing_store_suspend(
	boolean_t suspend);

extern kern_return_t macx_backing_store_recovery(
	int pid);

extern boolean_t swtch_pri(int pri);

extern boolean_t swtch(void);

extern kern_return_t thread_switch(
	mach_port_name_t thread_name,
	int option,
	mach_msg_timeout_t option_time);

extern mach_port_name_t task_self_trap(void);

extern kern_return_t host_create_mach_voucher_trap(
	mach_port_name_t host,
	mach_voucher_attr_raw_recipe_array_t recipes,
	int recipes_size,
	mach_port_name_t *voucher);

extern kern_return_t mach_voucher_extract_attr_recipe_trap(
	mach_port_name_t voucher_name,
	mach_voucher_attr_key_t key,
	mach_voucher_attr_raw_recipe_t recipe,
	mach_msg_type_number_t *recipe_size);

extern kern_return_t _kernelrpc_mach_port_type_trap(
	ipc_space_t task,
	mach_port_name_t name,
	mach_port_type_t *ptype);

extern kern_return_t _kernelrpc_mach_port_request_notification_trap(
	ipc_space_t task,
	mach_port_name_t name,
	mach_msg_id_t msgid,
	mach_port_mscount_t sync,
	mach_port_name_t notify,
	mach_msg_type_name_t notifyPoly,
	mach_port_name_t *previous);

/*
 *	Obsolete interfaces.
 */

extern kern_return_t task_for_pid(
	mach_port_name_t target_tport,
	int pid,
	mach_port_name_t *t);

extern kern_return_t task_name_for_pid(
	mach_port_name_t target_tport,
	int pid,
	mach_port_name_t *tn);

extern kern_return_t pid_for_task(
	mach_port_name_t t,
	int *x);

extern kern_return_t debug_control_port_for_pid(
	mach_port_name_t target_tport,
	int pid,
	mach_port_name_t *t);


__END_DECLS

#endif  /* _MACH_MACH_TRAPS_H_ */