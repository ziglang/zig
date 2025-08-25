/*
 * Copyright (c) 2023 Apple Inc. All rights reserved.
 *
 * @APPLE_APACHE_LICENSE_HEADER_START@
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * @APPLE_APACHE_LICENSE_HEADER_END@
 */

#ifndef _DISPATCH_SWIFT_SHIMS_
#define _DISPATCH_SWIFT_SHIMS_

#ifndef __DISPATCH_INDIRECT__
#error "This file is intended to be used only for Dispatch Swift Overlay."
#include <dispatch/base.h> // for HeaderDoc
#endif

DISPATCH_ASSUME_NONNULL_BEGIN
DISPATCH_ASSUME_ABI_SINGLE_BEGIN

__BEGIN_DECLS

#ifdef __swift__
DISPATCH_MALLOC DISPATCH_RETURNS_RETAINED DISPATCH_WARN_RESULT
DISPATCH_NOTHROW
DISPATCH_REFINED_FOR_SWIFT DISPATCH_SWIFT_NAME(DispatchSerialQueue.init(__label:attr:queue:))
static inline dispatch_queue_serial_t
dispatch_serial_queue_create_with_target_4swift(const char *_Nullable DISPATCH_UNSAFE_INDEXABLE label,
		dispatch_queue_attr_t _Nullable attr, dispatch_queue_t _Nullable target) {
	return dispatch_queue_create_with_target(label, attr, target);
}

DISPATCH_MALLOC DISPATCH_RETURNS_RETAINED DISPATCH_WARN_RESULT
DISPATCH_NOTHROW
DISPATCH_REFINED_FOR_SWIFT DISPATCH_SWIFT_NAME(DispatchConcurrentQueue.init(__label:attr:queue:))
static inline dispatch_queue_concurrent_t
dispatch_concurrent_queue_create_with_target_4swift(const char *_Nullable DISPATCH_UNSAFE_INDEXABLE label,
		dispatch_queue_attr_t _Nullable attr, dispatch_queue_t _Nullable target) {
	return dispatch_queue_create_with_target(label, attr, target);
}
#endif

__END_DECLS

DISPATCH_ASSUME_ABI_SINGLE_END
DISPATCH_ASSUME_NONNULL_END

#endif /* _DISPATCH_SWIFT_SHIMS_ */
