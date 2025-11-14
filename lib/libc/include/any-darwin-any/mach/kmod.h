/*
 * Copyright (c) 2000-2007 Apple Inc. All rights reserved.
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
 * NOTICE: This file was modified by SPARTA, Inc. in 2005 to introduce
 * support for mandatory and extensible security protections.  This notice
 * is included in support of clause 2.2 (b) of the Apple Public License,
 * Version 2.0.
 */

#ifndef    _MACH_KMOD_H_
#define    _MACH_KMOD_H_

#include <mach/kern_return.h>
#include <mach/mach_types.h>

#include <sys/cdefs.h>

__BEGIN_DECLS

#if PRAGMA_MARK
#pragma mark Basic macros & typedefs
#endif
/***********************************************************************
* Basic macros & typedefs
***********************************************************************/
#define KMOD_MAX_NAME    64

#define KMOD_RETURN_SUCCESS    KERN_SUCCESS
#define KMOD_RETURN_FAILURE    KERN_FAILURE

typedef int kmod_t;

struct  kmod_info;
typedef kern_return_t kmod_start_func_t(struct kmod_info * ki, void * data);
typedef kern_return_t kmod_stop_func_t(struct kmod_info * ki, void * data);

#if PRAGMA_MARK
#pragma mark Structure definitions
#endif
/***********************************************************************
* Structure definitions
*
* All structures must be #pragma pack(4).
***********************************************************************/
#pragma pack(push, 4)

/* Run-time struct only; never saved to a file */
typedef struct kmod_reference {
	struct kmod_reference * next;
	struct kmod_info      * info;
} kmod_reference_t;

/***********************************************************************
* Warning: Any changes to the kmod_info structure affect the
* KMOD_..._DECL macros below.
***********************************************************************/

/* The kmod_info_t structure is only safe to use inside the running
 * kernel.  If you need to work with a kmod_info_t structure outside
 * the kernel, please use the compatibility definitions below.
 */
typedef struct kmod_info {
	struct kmod_info  * next;
	int32_t             info_version;       // version of this structure
	uint32_t            id;
	char                name[KMOD_MAX_NAME];
	char                version[KMOD_MAX_NAME];
	int32_t             reference_count;    // # linkage refs to this
	kmod_reference_t  * reference_list;     // who this refs (links on)
	vm_address_t        address;            // starting address
	vm_size_t           size;               // total size
	vm_size_t           hdr_size;           // unwired hdr size
	kmod_start_func_t * start;
	kmod_stop_func_t  * stop;
} kmod_info_t;

/* A compatibility definition of kmod_info_t for 32-bit kexts.
 */
typedef struct kmod_info_32_v1 {
	uint32_t            next_addr;
	int32_t             info_version;
	uint32_t            id;
	uint8_t             name[KMOD_MAX_NAME];
	uint8_t             version[KMOD_MAX_NAME];
	int32_t             reference_count;
	uint32_t            reference_list_addr;
	uint32_t            address;
	uint32_t            size;
	uint32_t            hdr_size;
	uint32_t            start_addr;
	uint32_t            stop_addr;
} kmod_info_32_v1_t;

/* A compatibility definition of kmod_info_t for 64-bit kexts.
 */
typedef struct kmod_info_64_v1 {
	uint64_t            next_addr;
	int32_t             info_version;
	uint32_t            id;
	uint8_t             name[KMOD_MAX_NAME];
	uint8_t             version[KMOD_MAX_NAME];
	int32_t             reference_count;
	uint64_t            reference_list_addr;
	uint64_t            address;
	uint64_t            size;
	uint64_t            hdr_size;
	uint64_t            start_addr;
	uint64_t            stop_addr;
} kmod_info_64_v1_t;

#pragma pack(pop)

#if PRAGMA_MARK
#pragma mark Kmod structure declaration macros
#endif
/***********************************************************************
* Kmod structure declaration macros
***********************************************************************/
#define KMOD_INFO_NAME       kmod_info
#define KMOD_INFO_VERSION    1

#define KMOD_DECL(name, version)                                  \
    static kmod_start_func_t name ## _module_start;               \
    static kmod_stop_func_t  name ## _module_stop;                \
    kmod_info_t KMOD_INFO_NAME = { 0, KMOD_INFO_VERSION, -1U,      \
	               { #name }, { version }, -1, 0, 0, 0, 0,    \
	                   name ## _module_start,                 \
	                   name ## _module_stop };

#define KMOD_EXPLICIT_DECL(name, version, start, stop)            \
    kmod_info_t KMOD_INFO_NAME = { 0, KMOD_INFO_VERSION, -1U,      \
	               { #name }, { version }, -1, 0, 0, 0, 0,    \
	                   start, stop };

#if PRAGMA_MARK
#pragma mark Kernel private declarations
#endif
/***********************************************************************
* Kernel private declarations.
***********************************************************************/


#if PRAGMA_MARK
#pragma mark Obsolete kmod stuff
#endif
/***********************************************************************
* These 3 should be dropped but they're referenced by MIG declarations.
***********************************************************************/
typedef void * kmod_args_t;
typedef int kmod_control_flavor_t;
typedef kmod_info_t * kmod_info_array_t;

__END_DECLS

#endif    /* _MACH_KMOD_H_ */
