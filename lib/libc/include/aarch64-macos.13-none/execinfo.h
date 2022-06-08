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
#include <stddef.h>
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

/*!
 * @function backtrace_async
 * Extracts the function return addresses of the current call stack. While
 * backtrace() will only follow the OS call stack, backtrace_async() will
 * prefer the unwind the Swift concurrency continuation stack if invoked
 * from within an async context. In a non-async context this function is
 * strictly equivalent to backtrace().
 *
 * @param array
 * The array of pointers to fill with the return addresses.
 *
 * @param length
 * The maximum number of pointers to write.
 *
 * @param task_id
 * Can be NULL. If non-NULL, the uint32_t pointed to by `task_id` is set to
 * a non-zero value that for the current process uniquely identifies the async
 * task currently running. If called from a non-async context, the value is
 * set to 0 and `array` contains the same values backtrace() would return.
 *
 * Note that the continuation addresses provided by backtrace_async()
 * have an offset of 1 added to them.  Most symbolication engines will
 * substract 1 from the call stack return addresses in order to symbolicate
 * the call site rather than the return location.  With a Swift async
 * continuation, substracting 1 from its address would result in an address
 * in a different function.  This offset allows the returned addresses to be
 * handled correctly by most existing symbolication engines.
 *
 * @result
 * The number of pointers actually written.
 */
API_AVAILABLE(macosx(12.0), ios(15.0), tvos(15.0), watchos(8.0))
size_t backtrace_async(void** array, size_t length, uint32_t *task_id);

__END_DECLS

#endif /* !_EXECINFO_H_ */