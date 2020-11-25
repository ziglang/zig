/*
 * Copyright (c) 2017-2019 Apple Inc. All rights reserved.
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

#ifndef __DISPATCH_WORKLOOP__
#define __DISPATCH_WORKLOOP__

#ifndef __DISPATCH_INDIRECT__
#error "Please #include <dispatch/dispatch.h> instead of this file directly."
#include <dispatch/base.h> // for HeaderDoc
#endif

DISPATCH_ASSUME_NONNULL_BEGIN

__BEGIN_DECLS

/*!
 * @typedef dispatch_workloop_t
 *
 * @abstract
 * Dispatch workloops invoke workitems submitted to them in priority order.
 *
 * @discussion
 * A dispatch workloop is a flavor of dispatch_queue_t that is a priority
 * ordered queue (using the QOS class of the submitted workitems as the
 * ordering).
 *
 * Between each workitem invocation, the workloop will evaluate whether higher
 * priority workitems have since been submitted, either directly to the
 * workloop or to any queues that target the workloop, and execute these first.
 *
 * Serial queues targeting a workloop maintain FIFO execution of their
 * workitems. However, the workloop may reorder workitems submitted to
 * independent serial queues targeting it with respect to each other,
 * based on their priorities, while preserving FIFO execution with respect to
 * each serial queue.
 *
 * A dispatch workloop is a "subclass" of dispatch_queue_t which can be passed
 * to all APIs accepting a dispatch queue, except for functions from the
 * dispatch_sync() family. dispatch_async_and_wait() must be used for workloop
 * objects. Functions from the dispatch_sync() family on queues targeting
 * a workloop are still permitted but discouraged for performance reasons.
 */
DISPATCH_DECL_SUBCLASS(dispatch_workloop, dispatch_queue);

/*!
 * @function dispatch_workloop_create
 *
 * @abstract
 * Creates a new dispatch workloop to which workitems may be submitted.
 *
 * @param label
 * A string label to attach to the workloop.
 *
 * @result
 * The newly created dispatch workloop.
 */
API_AVAILABLE(macos(10.14), ios(12.0), tvos(12.0), watchos(5.0))
DISPATCH_EXPORT DISPATCH_MALLOC DISPATCH_RETURNS_RETAINED DISPATCH_WARN_RESULT
DISPATCH_NOTHROW
dispatch_workloop_t
dispatch_workloop_create(const char *_Nullable label);

/*!
 * @function dispatch_workloop_create_inactive
 *
 * @abstract
 * Creates a new inactive dispatch workloop that can be setup and then
 * activated.
 *
 * @discussion
 * Creating an inactive workloop allows for it to receive further configuration
 * before it is activated, and workitems can be submitted to it.
 *
 * Submitting workitems to an inactive workloop is undefined and will cause the
 * process to be terminated.
 *
 * @param label
 * A string label to attach to the workloop.
 *
 * @result
 * The newly created dispatch workloop.
 */
API_AVAILABLE(macos(10.14), ios(12.0), tvos(12.0), watchos(5.0))
DISPATCH_EXPORT DISPATCH_MALLOC DISPATCH_RETURNS_RETAINED DISPATCH_WARN_RESULT
DISPATCH_NOTHROW
dispatch_workloop_t
dispatch_workloop_create_inactive(const char *_Nullable label);

/*!
 * @function dispatch_workloop_set_autorelease_frequency
 *
 * @abstract
 * Sets the autorelease frequency of the workloop.
 *
 * @discussion
 * See dispatch_queue_attr_make_with_autorelease_frequency().
 * The default policy for a workloop is
 * DISPATCH_AUTORELEASE_FREQUENCY_WORK_ITEM.
 *
 * @param workloop
 * The dispatch workloop to modify.
 *
 * This workloop must be inactive, passing an activated object is undefined
 * and will cause the process to be terminated.
 *
 * @param frequency
 * The requested autorelease frequency.
 */
API_AVAILABLE(macos(10.14), ios(12.0), tvos(12.0), watchos(5.0))
DISPATCH_EXPORT DISPATCH_NONNULL_ALL DISPATCH_NOTHROW
void
dispatch_workloop_set_autorelease_frequency(dispatch_workloop_t workloop,
		dispatch_autorelease_frequency_t frequency);

__END_DECLS

DISPATCH_ASSUME_NONNULL_END

#endif
