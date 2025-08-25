/*
 * Copyright (c) 2016 Apple Computer, Inc. All rights reserved.
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

#ifndef _MACH_DYLIB_INFO_H_
#define _MACH_DYLIB_INFO_H_

#include <mach/boolean.h>
#include <stdint.h>
#include <sys/_types/_fsid_t.h>
#include <sys/_types/_u_int32_t.h>
#include <sys/_types/_fsobj_id_t.h>
#include <sys/_types/_uuid_t.h>

/* These definitions must be kept in sync with the ones in
 * osfmk/mach/mach_types.defs.
 */

struct dyld_kernel_image_info {
	uuid_t uuid;
	fsobj_id_t fsobjid;
	fsid_t fsid;
	uint64_t load_addr;
};

struct dyld_kernel_process_info {
	struct dyld_kernel_image_info cache_image_info;
	uint64_t timestamp;         // mach_absolute_time of last time dyld change to image list
	uint32_t imageCount;        // number of images currently loaded into process
	uint32_t initialImageCount; // number of images statically loaded into process (before any dlopen() calls)
	uint8_t dyldState;          // one of dyld_process_state_* values
	boolean_t no_cache;         // process is running without a dyld cache
	boolean_t private_cache;    // process is using a private copy of its dyld cache
};

/* typedefs so our MIG is sane */

typedef struct dyld_kernel_image_info dyld_kernel_image_info_t;
typedef struct dyld_kernel_process_info dyld_kernel_process_info_t;
typedef dyld_kernel_image_info_t *dyld_kernel_image_info_array_t;

#endif /* _MACH_DYLIB_INFO_H_ */
