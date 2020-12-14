/*
 * Copyright (c) 2008-2013 Apple Inc. All rights reserved.
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

#ifndef __DISPATCH_SEMAPHORE__
#define __DISPATCH_SEMAPHORE__

#ifndef __DISPATCH_INDIRECT__
#error "Please #include <dispatch/dispatch.h> instead of this file directly."
#include <dispatch/base.h> // for HeaderDoc
#endif

DISPATCH_ASSUME_NONNULL_BEGIN

/*!
 * @typedef dispatch_semaphore_t
 *
 * @abstract
 * A counting semaphore.
 */
DISPATCH_DECL(dispatch_semaphore);

__BEGIN_DECLS

/*!
 * @function dispatch_semaphore_create
 *
 * @abstract
 * Creates new counting semaphore with an initial value.
 *
 * @discussion
 * Passing zero for the value is useful for when two threads need to reconcile
 * the completion of a particular event. Passing a value greater than zero is
 * useful for managing a finite pool of resources, where the pool size is equal
 * to the value.
 *
 * @param value
 * The starting value for the semaphore. Passing a value less than zero will
 * cause NULL to be returned.
 *
 * @result
 * The newly created semaphore, or NULL on failure.
 */
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_MALLOC DISPATCH_RETURNS_RETAINED DISPATCH_WARN_RESULT
DISPATCH_NOTHROW
dispatch_semaphore_t
dispatch_semaphore_create(intptr_t value);

/*!
 * @function dispatch_semaphore_wait
 *
 * @abstract
 * Wait (decrement) for a semaphore.
 *
 * @discussion
 * Decrement the counting semaphore. If the resulting value is less than zero,
 * this function waits for a signal to occur before returning.
 *
 * @param dsema
 * The semaphore. The result of passing NULL in this parameter is undefined.
 *
 * @param timeout
 * When to timeout (see dispatch_time). As a convenience, there are the
 * DISPATCH_TIME_NOW and DISPATCH_TIME_FOREVER constants.
 *
 * @result
 * Returns zero on success, or non-zero if the timeout occurred.
 */
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_NONNULL_ALL DISPATCH_NOTHROW
intptr_t
dispatch_semaphore_wait(dispatch_semaphore_t dsema, dispatch_time_t timeout);

/*!
 * @function dispatch_semaphore_signal
 *
 * @abstract
 * Signal (increment) a semaphore.
 *
 * @discussion
 * Increment the counting semaphore. If the previous value was less than zero,
 * this function wakes a waiting thread before returning.
 *
 * @param dsema The counting semaphore.
 * The result of passing NULL in this parameter is undefined.
 *
 * @result
 * This function returns non-zero if a thread is woken. Otherwise, zero is
 * returned.
 */
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_NONNULL_ALL DISPATCH_NOTHROW
intptr_t
dispatch_semaphore_signal(dispatch_semaphore_t dsema);

__END_DECLS

DISPATCH_ASSUME_NONNULL_END

#endif /* __DISPATCH_SEMAPHORE__ */