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

#ifndef __DISPATCH_GROUP__
#define __DISPATCH_GROUP__

#ifndef __DISPATCH_INDIRECT__
#error "Please #include <dispatch/dispatch.h> instead of this file directly."
#include <dispatch/base.h> // for HeaderDoc
#endif

DISPATCH_ASSUME_NONNULL_BEGIN
DISPATCH_ASSUME_ABI_SINGLE_BEGIN

/*!
 * @typedef dispatch_group_t
 * @abstract
 * A group of blocks submitted to queues for asynchronous invocation.
 */
DISPATCH_DECL(dispatch_group);

__BEGIN_DECLS

/*!
 * @function dispatch_group_create
 *
 * @abstract
 * Creates new group with which blocks may be associated.
 *
 * @discussion
 * This function creates a new group with which blocks may be associated.
 * The dispatch group may be used to wait for the completion of the blocks it
 * references. The group object memory is freed with dispatch_release().
 *
 * @result
 * The newly created group, or NULL on failure.
 */
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_MALLOC DISPATCH_RETURNS_RETAINED DISPATCH_WARN_RESULT
DISPATCH_NOTHROW
dispatch_group_t
dispatch_group_create(void);

/*!
 * @function dispatch_group_async
 *
 * @abstract
 * Submits a block to a dispatch queue and associates the block with the given
 * dispatch group.
 *
 * @discussion
 * Submits a block to a dispatch queue and associates the block with the given
 * dispatch group. The dispatch group may be used to wait for the completion
 * of the blocks it references.
 *
 * @param group
 * A dispatch group to associate with the submitted block.
 * The result of passing NULL in this parameter is undefined.
 *
 * @param queue
 * The dispatch queue to which the block will be submitted for asynchronous
 * invocation.
 *
 * @param block
 * The block to perform asynchronously.
 */
#ifdef __BLOCKS__
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_NONNULL_ALL DISPATCH_NOTHROW
void
dispatch_group_async(dispatch_group_t group,
	dispatch_queue_t queue,
	dispatch_block_t block);
#endif /* __BLOCKS__ */

/*!
 * @function dispatch_group_async_f
 *
 * @abstract
 * Submits a function to a dispatch queue and associates the block with the
 * given dispatch group.
 *
 * @discussion
 * See dispatch_group_async() for details.
 *
 * @param group
 * A dispatch group to associate with the submitted function.
 * The result of passing NULL in this parameter is undefined.
 *
 * @param queue
 * The dispatch queue to which the function will be submitted for asynchronous
 * invocation.
 *
 * @param context
 * The application-defined context parameter to pass to the function.
 *
 * @param work
 * The application-defined function to invoke on the target queue. The first
 * parameter passed to this function is the context provided to
 * dispatch_group_async_f().
 */
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_NONNULL1 DISPATCH_NONNULL2 DISPATCH_NONNULL4
DISPATCH_NOTHROW
void
dispatch_group_async_f(dispatch_group_t group,
	dispatch_queue_t queue,
	void *_Nullable context,
	dispatch_function_t work);

/*!
 * @function dispatch_group_wait
 *
 * @abstract
 * Wait synchronously until all the blocks associated with a group have
 * completed or until the specified timeout has elapsed.
 *
 * @discussion
 * This function waits for the completion of the blocks associated with the
 * given dispatch group, and returns after all blocks have completed or when
 * the specified timeout has elapsed.
 *
 * This function will return immediately if there are no blocks associated
 * with the dispatch group (i.e. the group is empty).
 *
 * The result of calling this function from multiple threads simultaneously
 * with the same dispatch group is undefined.
 *
 * After the successful return of this function, the dispatch group is empty.
 * It may either be released with dispatch_release() or re-used for additional
 * blocks. See dispatch_group_async() for more information.
 *
 * @param group
 * The dispatch group to wait on.
 * The result of passing NULL in this parameter is undefined.
 *
 * @param timeout
 * When to timeout (see dispatch_time). As a convenience, there are the
 * DISPATCH_TIME_NOW and DISPATCH_TIME_FOREVER constants.
 *
 * @result
 * Returns zero on success (all blocks associated with the group completed
 * within the specified timeout) or non-zero on error (i.e. timed out).
 */
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_NONNULL_ALL DISPATCH_NOTHROW
intptr_t
dispatch_group_wait(dispatch_group_t group, dispatch_time_t timeout);

/*!
 * @function dispatch_group_notify
 *
 * @abstract
 * Schedule a block to be submitted to a queue when all the blocks associated
 * with a group have completed.
 *
 * @discussion
 * This function schedules a notification block to be submitted to the specified
 * queue once all blocks associated with the dispatch group have completed.
 *
 * If no blocks are associated with the dispatch group (i.e. the group is empty)
 * then the notification block will be submitted immediately.
 *
 * The group will be empty at the time the notification block is submitted to
 * the target queue. The group may either be released with dispatch_release()
 * or reused for additional operations.
 * See dispatch_group_async() for more information.
 *
 * @param group
 * The dispatch group to observe.
 * The result of passing NULL in this parameter is undefined.
 *
 * @param queue
 * The queue to which the supplied block will be submitted when the group
 * completes.
 *
 * @param block
 * The block to submit when the group completes.
 */
#ifdef __BLOCKS__
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_NONNULL_ALL DISPATCH_NOTHROW
void
dispatch_group_notify(dispatch_group_t group,
	dispatch_queue_t queue,
	dispatch_block_t block);
#endif /* __BLOCKS__ */

/*!
 * @function dispatch_group_notify_f
 *
 * @abstract
 * Schedule a function to be submitted to a queue when all the blocks
 * associated with a group have completed.
 *
 * @discussion
 * See dispatch_group_notify() for details.
 *
 * @param group
 * The dispatch group to observe.
 * The result of passing NULL in this parameter is undefined.
 *
 * @param context
 * The application-defined context parameter to pass to the function.
 *
 * @param work
 * The application-defined function to invoke on the target queue. The first
 * parameter passed to this function is the context provided to
 * dispatch_group_notify_f().
 */
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_NONNULL1 DISPATCH_NONNULL2 DISPATCH_NONNULL4
DISPATCH_NOTHROW
void
dispatch_group_notify_f(dispatch_group_t group,
	dispatch_queue_t queue,
	void *_Nullable context,
	dispatch_function_t work);

/*!
 * @function dispatch_group_enter
 *
 * @abstract
 * Manually indicate a block has entered the group
 *
 * @discussion
 * Calling this function indicates another block has joined the group through
 * a means other than dispatch_group_async(). Calls to this function must be
 * balanced with dispatch_group_leave().
 *
 * @param group
 * The dispatch group to update.
 * The result of passing NULL in this parameter is undefined.
 */
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_NONNULL_ALL DISPATCH_NOTHROW
void
dispatch_group_enter(dispatch_group_t group);

/*!
 * @function dispatch_group_leave
 *
 * @abstract
 * Manually indicate a block in the group has completed
 *
 * @discussion
 * Calling this function indicates block has completed and left the dispatch
 * group by a means other than dispatch_group_async().
 *
 * @param group
 * The dispatch group to update.
 * The result of passing NULL in this parameter is undefined.
 */
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_NONNULL_ALL DISPATCH_NOTHROW
void
dispatch_group_leave(dispatch_group_t group);

__END_DECLS

DISPATCH_ASSUME_ABI_SINGLE_END
DISPATCH_ASSUME_NONNULL_END

#endif