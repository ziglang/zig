/*
 * Copyright (c) 2007 Apple Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */
#ifndef _EXECINFO_H_
#define _EXECINFO_H_ 1

#include <sys/cdefs.h>
#include <Availability.h>
#include <os/base.h>
#include <os/availability.h>
#include <stdint.h>
#include <uuid/uuid.h>

__BEGIN_DECLS

int backtrace(void**,int) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);

API_AVAILABLE(macosx(10.14), ios(12.0), tvos(12.0), watchos(5.0))
OS_EXPORT
int backtrace_from_fp(void *startfp, void **array, int size);

char** backtrace_symbols(void* const*,int) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
void backtrace_symbols_fd(void* const*,int,int) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);

struct image_offset {
	/*
	 * The UUID of the image.
	 */
	uuid_t uuid;

	/*
	 * The offset is relative to the __TEXT section of the image.
	 */
	uint32_t offset;
};

API_AVAILABLE(macosx(10.14), ios(12.0), tvos(12.0), watchos(5.0))
OS_EXPORT
void backtrace_image_offsets(void* const* array,
		struct image_offset *image_offsets, int size);

__END_DECLS

#endif /* !_EXECINFO_H_ */