/*
 * Copyright (c) 2013 Apple Computer, Inc. All rights reserved.
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

#ifndef _MACH_VOUCHER_TYPES_H_
#define _MACH_VOUCHER_TYPES_H_

#include <mach/std_types.h>
#include <mach/port.h>
#include <mach/message.h>

/*
 * Mach Voucher - an immutable collection of attribute value handles.
 *
 * The mach voucher is such that it can be passed between processes
 * as a Mach port send right (by convention in the mach_msg_header_t’s
 * msgh_voucher field).
 *
 * You may construct a new mach voucher by passing a construction
 * recipe to host_create_mach_voucher().  The construction recipe supports
 * generic commands for copying, removing, and redeeming attribute value
 * handles from previous vouchers, or running attribute-mananger-specific
 * commands within the recipe.
 *
 * Once the set of attribute value handles is constructed and returned,
 * that set will not change for the life of the voucher (just because the
 * attribute value handle itself doesn't change, the value the handle refers
 * to is free to change at will).
 */
typedef mach_port_t             mach_voucher_t;
#define MACH_VOUCHER_NULL       ((mach_voucher_t) 0)

typedef mach_port_name_t        mach_voucher_name_t;
#define MACH_VOUCHER_NAME_NULL  ((mach_voucher_name_t) 0)

typedef mach_voucher_name_t     *mach_voucher_name_array_t;
#define MACH_VOUCHER_NAME_ARRAY_NULL ((mach_voucher_name_array_t) 0)

/*
 * This type changes appearance between user-space and kernel.  It is
 * a port at user-space and a reference to an ipc_voucher structure in-kernel.
 */
typedef mach_voucher_t          ipc_voucher_t;
#define IPC_VOUCHER_NULL        ((ipc_voucher_t) 0)

/*
 * mach_voucher_selector_t - A means of specifying which thread/task value to extract -
 *  the current voucher set at this level, or a voucher representing
 * the full [layered] effective value for the task/thread.
 */
typedef uint32_t mach_voucher_selector_t;
#define MACH_VOUCHER_SELECTOR_CURRENT           ((mach_voucher_selector_t)0)
#define MACH_VOUCHER_SELECTOR_EFFECTIVE         ((mach_voucher_selector_t)1)


/*
 * mach_voucher_attr_key_t - The key used to identify a particular managed resource or
 * to select the specific resource manager’s data associated
 * with a given voucher.
 */
typedef uint32_t mach_voucher_attr_key_t;
typedef mach_voucher_attr_key_t *mach_voucher_attr_key_array_t;

#define MACH_VOUCHER_ATTR_KEY_ALL               ((mach_voucher_attr_key_t)~0)
#define MACH_VOUCHER_ATTR_KEY_NONE              ((mach_voucher_attr_key_t)0)

/* other well-known-keys will be added here */
#define MACH_VOUCHER_ATTR_KEY_ATM               ((mach_voucher_attr_key_t)1)
#define MACH_VOUCHER_ATTR_KEY_IMPORTANCE        ((mach_voucher_attr_key_t)2)
#define MACH_VOUCHER_ATTR_KEY_BANK              ((mach_voucher_attr_key_t)3)
#define MACH_VOUCHER_ATTR_KEY_PTHPRIORITY       ((mach_voucher_attr_key_t)4)

#define MACH_VOUCHER_ATTR_KEY_USER_DATA         ((mach_voucher_attr_key_t)7)
#define MACH_VOUCHER_ATTR_KEY_BITS              MACH_VOUCHER_ATTR_KEY_USER_DATA /* deprecated */
#define MACH_VOUCHER_ATTR_KEY_TEST              ((mach_voucher_attr_key_t)8)

#define MACH_VOUCHER_ATTR_KEY_NUM_WELL_KNOWN    MACH_VOUCHER_ATTR_KEY_TEST

/*
 * mach_voucher_attr_content_t
 *
 * Data passed to a resource manager for modifying an attribute
 * value or returned from the resource manager in response to a
 * request to externalize the current value for that attribute.
 */
typedef uint8_t *mach_voucher_attr_content_t;
typedef uint32_t mach_voucher_attr_content_size_t;

/*
 * mach_voucher_attr_command_t - The private verbs implemented by each voucher
 * attribute manager via mach_voucher_attr_command().
 */
typedef uint32_t mach_voucher_attr_command_t;

/*
 * mach_voucher_attr_recipe_command_t
 *
 * The verbs used to create/morph a voucher attribute value.
 * We define some system-wide commands here - related to creation, and transport of
 * vouchers and attributes.  Additional commands can be defined by, and supported by,
 * individual attribute resource managers.
 */
typedef uint32_t mach_voucher_attr_recipe_command_t;
typedef mach_voucher_attr_recipe_command_t *mach_voucher_attr_recipe_command_array_t;

#define MACH_VOUCHER_ATTR_NOOP                  ((mach_voucher_attr_recipe_command_t)0)
#define MACH_VOUCHER_ATTR_COPY                  ((mach_voucher_attr_recipe_command_t)1)
#define MACH_VOUCHER_ATTR_REMOVE                ((mach_voucher_attr_recipe_command_t)2)
#define MACH_VOUCHER_ATTR_SET_VALUE_HANDLE      ((mach_voucher_attr_recipe_command_t)3)
#define MACH_VOUCHER_ATTR_AUTO_REDEEM           ((mach_voucher_attr_recipe_command_t)4)
#define MACH_VOUCHER_ATTR_SEND_PREPROCESS       ((mach_voucher_attr_recipe_command_t)5)

/* redeem is on its way out? */
#define MACH_VOUCHER_ATTR_REDEEM                ((mach_voucher_attr_recipe_command_t)10)

/* recipe command(s) for importance attribute manager */
#define MACH_VOUCHER_ATTR_IMPORTANCE_SELF       ((mach_voucher_attr_recipe_command_t)200)

/* recipe command(s) for bit-store attribute manager */
#define MACH_VOUCHER_ATTR_USER_DATA_STORE       ((mach_voucher_attr_recipe_command_t)211)
#define MACH_VOUCHER_ATTR_BITS_STORE            MACH_VOUCHER_ATTR_USER_DATA_STORE /* deprecated */

/* recipe command(s) for test attribute manager */
#define MACH_VOUCHER_ATTR_TEST_STORE            MACH_VOUCHER_ATTR_USER_DATA_STORE

/*
 * mach_voucher_attr_recipe_t
 *
 * An element in a recipe list to create a voucher.
 */
#pragma pack(push, 1)

typedef struct mach_voucher_attr_recipe_data {
	mach_voucher_attr_key_t                 key;
	mach_voucher_attr_recipe_command_t      command;
	mach_voucher_name_t                     previous_voucher;
	mach_voucher_attr_content_size_t        content_size;
	uint8_t                                 content[];
} mach_voucher_attr_recipe_data_t;
typedef mach_voucher_attr_recipe_data_t *mach_voucher_attr_recipe_t;
typedef mach_msg_type_number_t mach_voucher_attr_recipe_size_t;

/* Make the above palatable to MIG */
typedef uint8_t *mach_voucher_attr_raw_recipe_t;
typedef mach_voucher_attr_raw_recipe_t mach_voucher_attr_raw_recipe_array_t;
typedef mach_msg_type_number_t mach_voucher_attr_raw_recipe_size_t;
typedef mach_msg_type_number_t mach_voucher_attr_raw_recipe_array_size_t;

#define MACH_VOUCHER_ATTR_MAX_RAW_RECIPE_ARRAY_SIZE   5120
#define MACH_VOUCHER_TRAP_STACK_LIMIT                 256

#pragma pack(pop)

/*
 * VOUCHER ATTRIBUTE MANAGER Writer types
 */

/*
 * mach_voucher_attr_manager_t
 *
 * A handle through which the mach voucher mechanism communicates with the voucher
 * attribute manager for a given attribute key.
 */
typedef mach_port_t                     mach_voucher_attr_manager_t;
#define MACH_VOUCHER_ATTR_MANAGER_NULL  ((mach_voucher_attr_manager_t) 0)

/*
 * mach_voucher_attr_control_t
 *
 * A handle provided to the voucher attribute manager for a given attribute key
 * through which it makes inquiries or control operations of the mach voucher mechanism.
 */
typedef mach_port_t                     mach_voucher_attr_control_t;
#define MACH_VOUCHER_ATTR_CONTROL_NULL  ((mach_voucher_attr_control_t) 0)

/*
 * These types are different in-kernel vs user-space.  They are ports in user-space,
 * pointers to opaque structs in most of the kernel, and pointers to known struct
 * types in the Mach portion of the kernel.
 */
typedef mach_port_t             ipc_voucher_attr_manager_t;
typedef mach_port_t             ipc_voucher_attr_control_t;
#define IPC_VOUCHER_ATTR_MANAGER_NULL ((ipc_voucher_attr_manager_t) 0)
#define IPC_VOUCHER_ATTR_CONTROL_NULL ((ipc_voucher_attr_control_t) 0)

/*
 * mach_voucher_attr_value_handle_t
 *
 * The private handle that the voucher attribute manager provides to
 * the mach voucher mechanism to represent a given attr content/value.
 */
typedef uint64_t mach_voucher_attr_value_handle_t __kernel_ptr_semantics;
typedef mach_voucher_attr_value_handle_t *mach_voucher_attr_value_handle_array_t;

typedef mach_msg_type_number_t mach_voucher_attr_value_handle_array_size_t;
#define MACH_VOUCHER_ATTR_VALUE_MAX_NESTED      ((mach_voucher_attr_value_handle_array_size_t)4)

typedef uint32_t mach_voucher_attr_value_reference_t;
typedef uint32_t mach_voucher_attr_value_flags_t;
#define MACH_VOUCHER_ATTR_VALUE_FLAGS_NONE      ((mach_voucher_attr_value_flags_t)0)
#define MACH_VOUCHER_ATTR_VALUE_FLAGS_PERSIST   ((mach_voucher_attr_value_flags_t)1)

/* USE - TBD */
typedef uint32_t mach_voucher_attr_control_flags_t;
#define MACH_VOUCHER_ATTR_CONTROL_FLAGS_NONE    ((mach_voucher_attr_control_flags_t)0)

/*
 * Commands and types for the IPC Importance Attribute Manager
 *
 * These are the valid mach_voucher_attr_command() options with the
 * MACH_VOUCHER_ATTR_KEY_IMPORTANCE key.
 */
#define MACH_VOUCHER_IMPORTANCE_ATTR_ADD_EXTERNAL       1  /* Add some number of external refs (not supported) */
#define MACH_VOUCHER_IMPORTANCE_ATTR_DROP_EXTERNAL      2  /* Drop some number of external refs */
typedef uint32_t mach_voucher_attr_importance_refs;

/*
 * Activity id Generation defines
 */
#define MACH_ACTIVITY_ID_COUNT_MAX 16

#endif  /* _MACH_VOUCHER_TYPES_H_ */