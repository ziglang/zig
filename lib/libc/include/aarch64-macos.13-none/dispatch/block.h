/*
 * Copyright (c) 2014 Apple Inc. All rights reserved.
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

#ifndef __DISPATCH_BLOCK__
#define __DISPATCH_BLOCK__

#ifndef __DISPATCH_INDIRECT__
#error "Please #include <dispatch/dispatch.h> instead of this file directly."
#include <dispatch/base.h> // for HeaderDoc
#endif

#ifdef __BLOCKS__

/*!
 * @group Dispatch block objects
 */

DISPATCH_ASSUME_NONNULL_BEGIN
DISPATCH_ASSUME_ABI_SINGLE_BEGIN

__BEGIN_DECLS

/*!
 * @typedef dispatch_block_flags_t
 * Flags to pass to the dispatch_block_create* functions.
 *
 * @const DISPATCH_BLOCK_BARRIER
 * Flag indicating that a dispatch block object should act as a barrier block
 * when submitted to a DISPATCH_QUEUE_CONCURRENT queue.
 * See dispatch_barrier_async() for details.
 * This flag has no effect when the dispatch block object is invoked directly.
 *
 * @const DISPATCH_BLOCK_DETACHED
 * Flag indicating that a dispatch block object should execute disassociated
 * from current execution context attributes such as os_activity_t
 * and properties of the current IPC request (if any). With regard to QoS class,
 * the behavior is the same as for DISPATCH_BLOCK_NO_QOS. If invoked directly,
 * the block object will remove the other attributes from the calling thread for
 * the duration of the block body (before applying attributes assigned to the
 * block object, if any). If submitted to a queue, the block object will be
 * executed with the attributes of the queue (or any attributes specifically
 * assigned to the block object).
 *
 * @const DISPATCH_BLOCK_ASSIGN_CURRENT
 * Flag indicating that a dispatch block object should be assigned the execution
 * context attributes that are current at the time the block object is created.
 * This applies to attributes such as QOS class, os_activity_t and properties of
 * the current IPC request (if any). If invoked directly, the block object will
 * apply these attributes to the calling thread for the duration of the block
 * body. If the block object is submitted to a queue, this flag replaces the
 * default behavior of associating the submitted block instance with the
 * execution context attributes that are current at the time of submission.
 * If a specific QOS class is assigned with DISPATCH_BLOCK_NO_QOS_CLASS or
 * dispatch_block_create_with_qos_class(), that QOS class takes precedence over
 * the QOS class assignment indicated by this flag.
 *
 * @const DISPATCH_BLOCK_NO_QOS_CLASS
 * Flag indicating that a dispatch block object should be not be assigned a QOS
 * class. If invoked directly, the block object will be executed with the QOS
 * class of the calling thread. If the block object is submitted to a queue,
 * this replaces the default behavior of associating the submitted block
 * instance with the QOS class current at the time of submission.
 * This flag is ignored if a specific QOS class is assigned with
 * dispatch_block_create_with_qos_class().
 *
 * @const DISPATCH_BLOCK_INHERIT_QOS_CLASS
 * Flag indicating that execution of a dispatch block object submitted to a
 * queue should prefer the QOS class assigned to the queue over the QOS class
 * assigned to the block (resp. associated with the block at the time of
 * submission). The latter will only be used if the queue in question does not
 * have an assigned QOS class, as long as doing so does not result in a QOS
 * class lower than the QOS class inherited from the queue's target queue.
 * This flag is the default when a dispatch block object is submitted to a queue
 * for asynchronous execution and has no effect when the dispatch block object
 * is invoked directly. It is ignored if DISPATCH_BLOCK_ENFORCE_QOS_CLASS is
 * also passed.
 *
 * @const DISPATCH_BLOCK_ENFORCE_QOS_CLASS
 * Flag indicating that execution of a dispatch block object submitted to a
 * queue should prefer the QOS class assigned to the block (resp. associated
 * with the block at the time of submission) over the QOS class assigned to the
 * queue, as long as doing so will not result in a lower QOS class.
 * This flag is the default when a dispatch block object is submitted to a queue
 * for synchronous execution or when the dispatch block object is invoked
 * directly.
 */
DISPATCH_OPTIONS(dispatch_block_flags, unsigned long,
	DISPATCH_BLOCK_BARRIER
			DISPATCH_ENUM_API_AVAILABLE(macos(10.10), ios(8.0)) = 0x1,
	DISPATCH_BLOCK_DETACHED
			DISPATCH_ENUM_API_AVAILABLE(macos(10.10), ios(8.0)) = 0x2,
	DISPATCH_BLOCK_ASSIGN_CURRENT
			DISPATCH_ENUM_API_AVAILABLE(macos(10.10), ios(8.0)) = 0x4,
	DISPATCH_BLOCK_NO_QOS_CLASS
			DISPATCH_ENUM_API_AVAILABLE(macos(10.10), ios(8.0)) = 0x8,
	DISPATCH_BLOCK_INHERIT_QOS_CLASS
			DISPATCH_ENUM_API_AVAILABLE(macos(10.10), ios(8.0)) = 0x10,
	DISPATCH_BLOCK_ENFORCE_QOS_CLASS
			DISPATCH_ENUM_API_AVAILABLE(macos(10.10), ios(8.0)) = 0x20,
);

/*!
 * @function dispatch_block_create
 *
 * @abstract
 * Create a new dispatch block object on the heap from an existing block and
 * the given flags.
 *
 * @discussion
 * The provided block is Block_copy'ed to the heap and retained by the newly
 * created dispatch block object.
 *
 * The returned dispatch block object is intended to be submitted to a dispatch
 * queue with dispatch_async() and related functions, but may also be invoked
 * directly. Both operations can be performed an arbitrary number of times but
 * only the first completed execution of a dispatch block object can be waited
 * on with dispatch_block_wait() or observed with dispatch_block_notify().
 *
 * If the returned dispatch block object is submitted to a dispatch queue, the
 * submitted block instance will be associated with the QOS class current at the
 * time of submission, unless one of the following flags assigned a specific QOS
 * class (or no QOS class) at the time of block creation:
 *  - DISPATCH_BLOCK_ASSIGN_CURRENT
 *  - DISPATCH_BLOCK_NO_QOS_CLASS
 *  - DISPATCH_BLOCK_DETACHED
 * The QOS class the block object will be executed with also depends on the QOS
 * class assigned to the queue and which of the following flags was specified or
 * defaulted to:
 *  - DISPATCH_BLOCK_INHERIT_QOS_CLASS (default for asynchronous execution)
 *  - DISPATCH_BLOCK_ENFORCE_QOS_CLASS (default for synchronous execution)
 * See description of dispatch_block_flags_t for details.
 *
 * If the returned dispatch block object is submitted directly to a serial queue
 * and is configured to execute with a specific QOS class, the system will make
 * a best effort to apply the necessary QOS overrides to ensure that blocks
 * submitted earlier to the serial queue are executed at that same QOS class or
 * higher.
 *
 * @param flags
 * Configuration flags for the block object.
 * Passing a value that is not a bitwise OR of flags from dispatch_block_flags_t
 * results in NULL being returned.
 *
 * @param block
 * The block to create the dispatch block object from.
 *
 * @result
 * The newly created dispatch block object, or NULL.
 * When not building with Objective-C ARC, must be released with a -[release]
 * message or the Block_release() function.
 */
API_AVAILABLE(macos(10.10), ios(8.0))
DISPATCH_EXPORT DISPATCH_NONNULL2 DISPATCH_RETURNS_RETAINED_BLOCK
DISPATCH_WARN_RESULT DISPATCH_NOTHROW
dispatch_block_t
dispatch_block_create(dispatch_block_flags_t flags, dispatch_block_t block);

/*!
 * @function dispatch_block_create_with_qos_class
 *
 * @abstract
 * Create a new dispatch block object on the heap from an existing block and
 * the given flags, and assign it the specified QOS class and relative priority.
 *
 * @discussion
 * The provided block is Block_copy'ed to the heap and retained by the newly
 * created dispatch block object.
 *
 * The returned dispatch block object is intended to be submitted to a dispatch
 * queue with dispatch_async() and related functions, but may also be invoked
 * directly. Both operations can be performed an arbitrary number of times but
 * only the first completed execution of a dispatch block object can be waited
 * on with dispatch_block_wait() or observed with dispatch_block_notify().
 *
 * If invoked directly, the returned dispatch block object will be executed with
 * the assigned QOS class as long as that does not result in a lower QOS class
 * than what is current on the calling thread.
 *
 * If the returned dispatch block object is submitted to a dispatch queue, the
 * QOS class it will be executed with depends on the QOS class assigned to the
 * block, the QOS class assigned to the queue and which of the following flags
 * was specified or defaulted to:
 *  - DISPATCH_BLOCK_INHERIT_QOS_CLASS: default for asynchronous execution
 *  - DISPATCH_BLOCK_ENFORCE_QOS_CLASS: default for synchronous execution
 * See description of dispatch_block_flags_t for details.
 *
 * If the returned dispatch block object is submitted directly to a serial queue
 * and is configured to execute with a specific QOS class, the system will make
 * a best effort to apply the necessary QOS overrides to ensure that blocks
 * submitted earlier to the serial queue are executed at that same QOS class or
 * higher.
 *
 * @param flags
 * Configuration flags for the new block object.
 * Passing a value that is not a bitwise OR of flags from dispatch_block_flags_t
 * results in NULL being returned.
 *
 * @param qos_class
 * A QOS class value:
 *  - QOS_CLASS_USER_INTERACTIVE
 *  - QOS_CLASS_USER_INITIATED
 *  - QOS_CLASS_DEFAULT
 *  - QOS_CLASS_UTILITY
 *  - QOS_CLASS_BACKGROUND
 *  - QOS_CLASS_UNSPECIFIED
 * Passing QOS_CLASS_UNSPECIFIED is equivalent to specifying the
 * DISPATCH_BLOCK_NO_QOS_CLASS flag. Passing any other value results in NULL
 * being returned.
 *
 * @param relative_priority
 * A relative priority within the QOS class. This value is a negative
 * offset from the maximum supported scheduler priority for the given class.
 * Passing a value greater than zero or less than QOS_MIN_RELATIVE_PRIORITY
 * results in NULL being returned.
 *
 * @param block
 * The block to create the dispatch block object from.
 *
 * @result
 * The newly created dispatch block object, or NULL.
 * When not building with Objective-C ARC, must be released with a -[release]
 * message or the Block_release() function.
 */
API_AVAILABLE(macos(10.10), ios(8.0))
DISPATCH_EXPORT DISPATCH_NONNULL4 DISPATCH_RETURNS_RETAINED_BLOCK
DISPATCH_WARN_RESULT DISPATCH_NOTHROW
dispatch_block_t
dispatch_block_create_with_qos_class(dispatch_block_flags_t flags,
		dispatch_qos_class_t qos_class, int relative_priority,
		dispatch_block_t block);

/*!
 * @function dispatch_block_perform
 *
 * @abstract
 * Create, synchronously execute and release a dispatch block object from the
 * specified block and flags.
 *
 * @discussion
 * Behaves identically to the sequence
 * <code>
 * dispatch_block_t b = dispatch_block_create(flags, block);
 * b();
 * Block_release(b);
 * </code>
 * but may be implemented more efficiently internally by not requiring a copy
 * to the heap of the specified block or the allocation of a new block object.
 *
 * @param flags
 * Configuration flags for the temporary block object.
 * The result of passing a value that is not a bitwise OR of flags from
 * dispatch_block_flags_t is undefined.
 *
 * @param block
 * The block to create the temporary block object from.
 */
API_AVAILABLE(macos(10.10), ios(8.0))
DISPATCH_EXPORT DISPATCH_NONNULL2 DISPATCH_NOTHROW
void
dispatch_block_perform(dispatch_block_flags_t flags,
		DISPATCH_NOESCAPE dispatch_block_t block);

/*!
 * @function dispatch_block_wait
 *
 * @abstract
 * Wait synchronously until execution of the specified dispatch block object has
 * completed or until the specified timeout has elapsed.
 *
 * @discussion
 * This function will return immediately if execution of the block object has
 * already completed.
 *
 * It is not possible to wait for multiple executions of the same block object
 * with this interface; use dispatch_group_wait() for that purpose. A single
 * dispatch block object may either be waited on once and executed once,
 * or it may be executed any number of times. The behavior of any other
 * combination is undefined. Submission to a dispatch queue counts as an
 * execution, even if cancellation (dispatch_block_cancel) means the block's
 * code never runs.
 *
 * The result of calling this function from multiple threads simultaneously
 * with the same dispatch block object is undefined, but note that doing so
 * would violate the rules described in the previous paragraph.
 *
 * If this function returns indicating that the specified timeout has elapsed,
 * then that invocation does not count as the one allowed wait.
 *
 * If at the time this function is called, the specified dispatch block object
 * has been submitted directly to a serial queue, the system will make a best
 * effort to apply the necessary QOS overrides to ensure that the block and any
 * blocks submitted earlier to that serial queue are executed at the QOS class
 * (or higher) of the thread calling dispatch_block_wait().
 *
 * @param block
 * The dispatch block object to wait on.
 * The result of passing NULL or a block object not returned by one of the
 * dispatch_block_create* functions is undefined.
 *
 * @param timeout
 * When to timeout (see dispatch_time). As a convenience, there are the
 * DISPATCH_TIME_NOW and DISPATCH_TIME_FOREVER constants.
 *
 * @result
 * Returns zero on success (the dispatch block object completed within the
 * specified timeout) or non-zero on error (i.e. timed out).
 */
API_AVAILABLE(macos(10.10), ios(8.0))
DISPATCH_EXPORT DISPATCH_NONNULL1 DISPATCH_NOTHROW
intptr_t
dispatch_block_wait(dispatch_block_t block, dispatch_time_t timeout);

/*!
 * @function dispatch_block_notify
 *
 * @abstract
 * Schedule a notification block to be submitted to a queue when the execution
 * of a specified dispatch block object has completed.
 *
 * @discussion
 * This function will submit the notification block immediately if execution of
 * the observed block object has already completed.
 *
 * It is not possible to be notified of multiple executions of the same block
 * object with this interface, use dispatch_group_notify() for that purpose.
 *
 * A single dispatch block object may either be observed one or more times
 * and executed once, or it may be executed any number of times. The behavior
 * of any other combination is undefined. Submission to a dispatch queue
 * counts as an execution, even if cancellation (dispatch_block_cancel) means
 * the block's code never runs.
 *
 * If multiple notification blocks are scheduled for a single block object,
 * there is no defined order in which the notification blocks will be submitted
 * to their associated queues.
 *
 * @param block
 * The dispatch block object to observe.
 * The result of passing NULL or a block object not returned by one of the
 * dispatch_block_create* functions is undefined.
 *
 * @param queue
 * The queue to which the supplied notification block will be submitted when
 * the observed block completes.
 *
 * @param notification_block
 * The notification block to submit when the observed block object completes.
 */
API_AVAILABLE(macos(10.10), ios(8.0))
DISPATCH_EXPORT DISPATCH_NONNULL_ALL DISPATCH_NOTHROW
void
dispatch_block_notify(dispatch_block_t block, dispatch_queue_t queue,
		dispatch_block_t notification_block);

/*!
 * @function dispatch_block_cancel
 *
 * @abstract
 * Asynchronously cancel the specified dispatch block object.
 *
 * @discussion
 * Cancellation causes any future execution of the dispatch block object to
 * return immediately, but does not affect any execution of the block object
 * that is already in progress.
 *
 * Release of any resources associated with the block object will be delayed
 * until execution of the block object is next attempted (or any execution
 * already in progress completes).
 *
 * NOTE: care needs to be taken to ensure that a block object that may be
 *       canceled does not capture any resources that require execution of the
 *       block body in order to be released (e.g. memory allocated with
 *       malloc(3) that the block body calls free(3) on). Such resources will
 *       be leaked if the block body is never executed due to cancellation.
 *
 * @param block
 * The dispatch block object to cancel.
 * The result of passing NULL or a block object not returned by one of the
 * dispatch_block_create* functions is undefined.
 */
API_AVAILABLE(macos(10.10), ios(8.0))
DISPATCH_EXPORT DISPATCH_NONNULL_ALL DISPATCH_NOTHROW
void
dispatch_block_cancel(dispatch_block_t block);

/*!
 * @function dispatch_block_testcancel
 *
 * @abstract
 * Tests whether the given dispatch block object has been canceled.
 *
 * @param block
 * The dispatch block object to test.
 * The result of passing NULL or a block object not returned by one of the
 * dispatch_block_create* functions is undefined.
 *
 * @result
 * Non-zero if canceled and zero if not canceled.
 */
API_AVAILABLE(macos(10.10), ios(8.0))
DISPATCH_EXPORT DISPATCH_NONNULL_ALL DISPATCH_WARN_RESULT DISPATCH_PURE
DISPATCH_NOTHROW
intptr_t
dispatch_block_testcancel(dispatch_block_t block);

__END_DECLS

DISPATCH_ASSUME_ABI_SINGLE_END
DISPATCH_ASSUME_NONNULL_END

#endif // __BLOCKS__

#endif // __DISPATCH_BLOCK__