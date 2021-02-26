/*
 * Copyright (c) 2009-2013 Apple Inc. All rights reserved.
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

#ifndef __DISPATCH_IO__
#define __DISPATCH_IO__

#ifndef __DISPATCH_INDIRECT__
#error "Please #include <dispatch/dispatch.h> instead of this file directly."
#include <dispatch/base.h> // for HeaderDoc
#endif

DISPATCH_ASSUME_NONNULL_BEGIN

__BEGIN_DECLS

/*! @header
 * Dispatch I/O provides both stream and random access asynchronous read and
 * write operations on file descriptors. One or more dispatch I/O channels may
 * be created from a file descriptor as either the DISPATCH_IO_STREAM type or
 * DISPATCH_IO_RANDOM type. Once a channel has been created the application may
 * schedule asynchronous read and write operations.
 *
 * The application may set policies on the dispatch I/O channel to indicate the
 * desired frequency of I/O handlers for long-running operations.
 *
 * Dispatch I/O also provides a memory management model for I/O buffers that
 * avoids unnecessary copying of data when pipelined between channels. Dispatch
 * I/O monitors the overall memory pressure and I/O access patterns for the
 * application to optimize resource utilization.
 */

/*!
 * @typedef dispatch_fd_t
 * Native file descriptor type for the platform.
 */
#if defined(_WIN32)
typedef intptr_t dispatch_fd_t;
#else
typedef int dispatch_fd_t;
#endif

/*!
 * @functiongroup Dispatch I/O Convenience API
 * Convenience wrappers around the dispatch I/O channel API, with simpler
 * callback handler semantics and no explicit management of channel objects.
 * File descriptors passed to the convenience API are treated as streams, and
 * scheduling multiple operations on one file descriptor via the convenience API
 * may incur more overhead than by using the dispatch I/O channel API directly.
 */

#ifdef __BLOCKS__
/*!
 * @function dispatch_read
 * Schedule a read operation for asynchronous execution on the specified file
 * descriptor. The specified handler is enqueued with the data read from the
 * file descriptor when the operation has completed or an error occurs.
 *
 * The data object passed to the handler will be automatically released by the
 * system when the handler returns. It is the responsibility of the application
 * to retain, concatenate or copy the data object if it is needed after the
 * handler returns.
 *
 * The data object passed to the handler will only contain as much data as is
 * currently available from the file descriptor (up to the specified length).
 *
 * If an unrecoverable error occurs on the file descriptor, the handler will be
 * enqueued with the appropriate error code along with a data object of any data
 * that could be read successfully.
 *
 * An invocation of the handler with an error code of zero and an empty data
 * object indicates that EOF was reached.
 *
 * The system takes control of the file descriptor until the handler is
 * enqueued, and during this time file descriptor flags such as O_NONBLOCK will
 * be modified by the system on behalf of the application. It is an error for
 * the application to modify a file descriptor directly while it is under the
 * control of the system, but it may create additional dispatch I/O convenience
 * operations or dispatch I/O channels associated with that file descriptor.
 *
 * @param fd		The file descriptor from which to read the data.
 * @param length	The length of data to read from the file descriptor,
 *			or SIZE_MAX to indicate that all of the data currently
 *			available from the file descriptor should be read.
 * @param queue		The dispatch queue to which the handler should be
 *			submitted.
 * @param handler	The handler to enqueue when data is ready to be
 *			delivered.
 *		param data	The data read from the file descriptor.
 *		param error	An errno condition for the read operation or
 *				zero if the read was successful.
 */
API_AVAILABLE(macos(10.7), ios(5.0))
DISPATCH_EXPORT DISPATCH_NONNULL3 DISPATCH_NONNULL4 DISPATCH_NOTHROW
void
dispatch_read(dispatch_fd_t fd,
	size_t length,
	dispatch_queue_t queue,
	void (^handler)(dispatch_data_t data, int error));

/*!
 * @function dispatch_write
 * Schedule a write operation for asynchronous execution on the specified file
 * descriptor. The specified handler is enqueued when the operation has
 * completed or an error occurs.
 *
 * If an unrecoverable error occurs on the file descriptor, the handler will be
 * enqueued with the appropriate error code along with the data that could not
 * be successfully written.
 *
 * An invocation of the handler with an error code of zero indicates that the
 * data was fully written to the channel.
 *
 * The system takes control of the file descriptor until the handler is
 * enqueued, and during this time file descriptor flags such as O_NONBLOCK will
 * be modified by the system on behalf of the application. It is an error for
 * the application to modify a file descriptor directly while it is under the
 * control of the system, but it may create additional dispatch I/O convenience
 * operations or dispatch I/O channels associated with that file descriptor.
 *
 * @param fd		The file descriptor to which to write the data.
 * @param data		The data object to write to the file descriptor.
 * @param queue		The dispatch queue to which the handler should be
 *			submitted.
 * @param handler	The handler to enqueue when the data has been written.
 *		param data	The data that could not be written to the I/O
 *				channel, or NULL.
 *		param error	An errno condition for the write operation or
 *				zero if the write was successful.
 */
API_AVAILABLE(macos(10.7), ios(5.0))
DISPATCH_EXPORT DISPATCH_NONNULL2 DISPATCH_NONNULL3 DISPATCH_NONNULL4
DISPATCH_NOTHROW
void
dispatch_write(dispatch_fd_t fd,
	dispatch_data_t data,
	dispatch_queue_t queue,
	void (^handler)(dispatch_data_t _Nullable data, int error));
#endif /* __BLOCKS__ */

/*!
 * @functiongroup Dispatch I/O Channel API
 */

/*!
 * @typedef dispatch_io_t
 * A dispatch I/O channel represents the asynchronous I/O policy applied to a
 * file descriptor. I/O channels are first class dispatch objects and may be
 * retained and released, suspended and resumed, etc.
 */
DISPATCH_DECL(dispatch_io);

/*!
 * @typedef dispatch_io_type_t
 * The type of a dispatch I/O channel:
 *
 * @const DISPATCH_IO_STREAM	A dispatch I/O channel representing a stream of
 * bytes. Read and write operations on a channel of this type are performed
 * serially (in order of creation) and read/write data at the file pointer
 * position that is current at the time the operation starts executing.
 * Operations of different type (read vs. write) may be performed simultaneously.
 * Offsets passed to operations on a channel of this type are ignored.
 *
 * @const DISPATCH_IO_RANDOM	A dispatch I/O channel representing a random
 * access file. Read and write operations on a channel of this type may be
 * performed concurrently and read/write data at the specified offset. Offsets
 * are interpreted relative to the file pointer position current at the time the
 * I/O channel is created. Attempting to create a channel of this type for a
 * file descriptor that is not seekable will result in an error.
 */
#define DISPATCH_IO_STREAM 0
#define DISPATCH_IO_RANDOM 1

typedef unsigned long dispatch_io_type_t;

#ifdef __BLOCKS__
/*!
 * @function dispatch_io_create
 * Create a dispatch I/O channel associated with a file descriptor. The system
 * takes control of the file descriptor until the channel is closed, an error
 * occurs on the file descriptor or all references to the channel are released.
 * At that time the specified cleanup handler will be enqueued and control over
 * the file descriptor relinquished.
 *
 * While a file descriptor is under the control of a dispatch I/O channel, file
 * descriptor flags such as O_NONBLOCK will be modified by the system on behalf
 * of the application. It is an error for the application to modify a file
 * descriptor directly while it is under the control of a dispatch I/O channel,
 * but it may create additional channels associated with that file descriptor.
 *
 * @param type	The desired type of I/O channel (DISPATCH_IO_STREAM
 *		or DISPATCH_IO_RANDOM).
 * @param fd	The file descriptor to associate with the I/O channel.
 * @param queue	The dispatch queue to which the handler should be submitted.
 * @param cleanup_handler	The handler to enqueue when the system
 *				relinquishes control over the file descriptor.
 *	param error		An errno condition if control is relinquished
 *				because channel creation failed, zero otherwise.
 * @result	The newly created dispatch I/O channel or NULL if an error
 *		occurred (invalid type specified).
 */
API_AVAILABLE(macos(10.7), ios(5.0))
DISPATCH_EXPORT DISPATCH_MALLOC DISPATCH_RETURNS_RETAINED DISPATCH_WARN_RESULT
DISPATCH_NOTHROW
dispatch_io_t
dispatch_io_create(dispatch_io_type_t type,
	dispatch_fd_t fd,
	dispatch_queue_t queue,
	void (^cleanup_handler)(int error));

/*!
 * @function dispatch_io_create_with_path
 * Create a dispatch I/O channel associated with a path name. The specified
 * path, oflag and mode parameters will be passed to open(2) when the first I/O
 * operation on the channel is ready to execute and the resulting file
 * descriptor will remain open and under the control of the system until the
 * channel is closed, an error occurs on the file descriptor or all references
 * to the channel are released. At that time the file descriptor will be closed
 * and the specified cleanup handler will be enqueued.
 *
 * @param type	The desired type of I/O channel (DISPATCH_IO_STREAM
 *		or DISPATCH_IO_RANDOM).
 * @param path	The absolute path to associate with the I/O channel.
 * @param oflag	The flags to pass to open(2) when opening the file at
 *		path.
 * @param mode	The mode to pass to open(2) when creating the file at
 *		path (i.e. with flag O_CREAT), zero otherwise.
 * @param queue	The dispatch queue to which the handler should be
 *		submitted.
 * @param cleanup_handler	The handler to enqueue when the system
 *				has closed the file at path.
 *	param error		An errno condition if control is relinquished
 *				because channel creation or opening of the
 *				specified file failed, zero otherwise.
 * @result	The newly created dispatch I/O channel or NULL if an error
 *		occurred (invalid type or non-absolute path specified).
 */
API_AVAILABLE(macos(10.7), ios(5.0))
DISPATCH_EXPORT DISPATCH_NONNULL2 DISPATCH_MALLOC DISPATCH_RETURNS_RETAINED
DISPATCH_WARN_RESULT DISPATCH_NOTHROW
dispatch_io_t
dispatch_io_create_with_path(dispatch_io_type_t type,
	const char *path, int oflag, mode_t mode,
	dispatch_queue_t queue,
	void (^cleanup_handler)(int error));

/*!
 * @function dispatch_io_create_with_io
 * Create a new dispatch I/O channel from an existing dispatch I/O channel.
 * The new channel inherits the file descriptor or path name associated with
 * the existing channel, but not its channel type or policies.
 *
 * If the existing channel is associated with a file descriptor, control by the
 * system over that file descriptor is extended until the new channel is also
 * closed, an error occurs on the file descriptor, or all references to both
 * channels are released. At that time the specified cleanup handler will be
 * enqueued and control over the file descriptor relinquished.
 *
 * While a file descriptor is under the control of a dispatch I/O channel, file
 * descriptor flags such as O_NONBLOCK will be modified by the system on behalf
 * of the application. It is an error for the application to modify a file
 * descriptor directly while it is under the control of a dispatch I/O channel,
 * but it may create additional channels associated with that file descriptor.
 *
 * @param type	The desired type of I/O channel (DISPATCH_IO_STREAM
 *		or DISPATCH_IO_RANDOM).
 * @param io	The existing channel to create the new I/O channel from.
 * @param queue	The dispatch queue to which the handler should be submitted.
 * @param cleanup_handler	The handler to enqueue when the system
 *				relinquishes control over the file descriptor
 *				(resp. closes the file at path) associated with
 *				the existing channel.
 *	param error		An errno condition if control is relinquished
 *				because channel creation failed, zero otherwise.
 * @result	The newly created dispatch I/O channel or NULL if an error
 *		occurred (invalid type specified).
 */
API_AVAILABLE(macos(10.7), ios(5.0))
DISPATCH_EXPORT DISPATCH_NONNULL2 DISPATCH_MALLOC DISPATCH_RETURNS_RETAINED
DISPATCH_WARN_RESULT DISPATCH_NOTHROW
dispatch_io_t
dispatch_io_create_with_io(dispatch_io_type_t type,
	dispatch_io_t io,
	dispatch_queue_t queue,
	void (^cleanup_handler)(int error));

/*!
 * @typedef dispatch_io_handler_t
 * The prototype of I/O handler blocks for dispatch I/O operations.
 *
 * @param done		A flag indicating whether the operation is complete.
 * @param data		The data object to be handled.
 * @param error		An errno condition for the operation.
 */
typedef void (^dispatch_io_handler_t)(bool done, dispatch_data_t _Nullable data,
		int error);

/*!
 * @function dispatch_io_read
 * Schedule a read operation for asynchronous execution on the specified I/O
 * channel. The I/O handler is enqueued one or more times depending on the
 * general load of the system and the policy specified on the I/O channel.
 *
 * Any data read from the channel is described by the dispatch data object
 * passed to the I/O handler. This object will be automatically released by the
 * system when the I/O handler returns. It is the responsibility of the
 * application to retain, concatenate or copy the data object if it is needed
 * after the I/O handler returns.
 *
 * Dispatch I/O handlers are not reentrant. The system will ensure that no new
 * I/O handler instance is invoked until the previously enqueued handler block
 * has returned.
 *
 * An invocation of the I/O handler with the done flag set indicates that the
 * read operation is complete and that the handler will not be enqueued again.
 *
 * If an unrecoverable error occurs on the I/O channel's underlying file
 * descriptor, the I/O handler will be enqueued with the done flag set, the
 * appropriate error code and a NULL data object.
 *
 * An invocation of the I/O handler with the done flag set, an error code of
 * zero and an empty data object indicates that EOF was reached.
 *
 * @param channel	The dispatch I/O channel from which to read the data.
 * @param offset	The offset relative to the channel position from which
 *			to start reading (only for DISPATCH_IO_RANDOM).
 * @param length	The length of data to read from the I/O channel, or
 *			SIZE_MAX to indicate that data should be read until EOF
 *			is reached.
 * @param queue		The dispatch queue to which the I/O handler should be
 *			submitted.
 * @param io_handler	The I/O handler to enqueue when data is ready to be
 *			delivered.
 *	param done	A flag indicating whether the operation is complete.
 *	param data	An object with the data most recently read from the
 *			I/O channel as part of this read operation, or NULL.
 *	param error	An errno condition for the read operation or zero if
 *			the read was successful.
 */
API_AVAILABLE(macos(10.7), ios(5.0))
DISPATCH_EXPORT DISPATCH_NONNULL1 DISPATCH_NONNULL4 DISPATCH_NONNULL5
DISPATCH_NOTHROW
void
dispatch_io_read(dispatch_io_t channel,
	off_t offset,
	size_t length,
	dispatch_queue_t queue,
	dispatch_io_handler_t io_handler);

/*!
 * @function dispatch_io_write
 * Schedule a write operation for asynchronous execution on the specified I/O
 * channel. The I/O handler is enqueued one or more times depending on the
 * general load of the system and the policy specified on the I/O channel.
 *
 * Any data remaining to be written to the I/O channel is described by the
 * dispatch data object passed to the I/O handler. This object will be
 * automatically released by the system when the I/O handler returns. It is the
 * responsibility of the application to retain, concatenate or copy the data
 * object if it is needed after the I/O handler returns.
 *
 * Dispatch I/O handlers are not reentrant. The system will ensure that no new
 * I/O handler instance is invoked until the previously enqueued handler block
 * has returned.
 *
 * An invocation of the I/O handler with the done flag set indicates that the
 * write operation is complete and that the handler will not be enqueued again.
 *
 * If an unrecoverable error occurs on the I/O channel's underlying file
 * descriptor, the I/O handler will be enqueued with the done flag set, the
 * appropriate error code and an object containing the data that could not be
 * written.
 *
 * An invocation of the I/O handler with the done flag set and an error code of
 * zero indicates that the data was fully written to the channel.
 *
 * @param channel	The dispatch I/O channel on which to write the data.
 * @param offset	The offset relative to the channel position from which
 *			to start writing (only for DISPATCH_IO_RANDOM).
 * @param data		The data to write to the I/O channel. The data object
 *			will be retained by the system until the write operation
 *			is complete.
 * @param queue		The dispatch queue to which the I/O handler should be
 *			submitted.
 * @param io_handler	The I/O handler to enqueue when data has been delivered.
 *	param done	A flag indicating whether the operation is complete.
 *	param data	An object of the data remaining to be
 *			written to the I/O channel as part of this write
 *			operation, or NULL.
 *	param error	An errno condition for the write operation or zero
 *			if the write was successful.
 */
API_AVAILABLE(macos(10.7), ios(5.0))
DISPATCH_EXPORT DISPATCH_NONNULL1 DISPATCH_NONNULL3 DISPATCH_NONNULL4
DISPATCH_NONNULL5 DISPATCH_NOTHROW
void
dispatch_io_write(dispatch_io_t channel,
	off_t offset,
	dispatch_data_t data,
	dispatch_queue_t queue,
	dispatch_io_handler_t io_handler);
#endif /* __BLOCKS__ */

/*!
 * @typedef dispatch_io_close_flags_t
 * The type of flags you can set on a dispatch_io_close() call
 *
 * @const DISPATCH_IO_STOP	Stop outstanding operations on a channel when
 *				the channel is closed.
 */
#define DISPATCH_IO_STOP 0x1

typedef unsigned long dispatch_io_close_flags_t;

/*!
 * @function dispatch_io_close
 * Close the specified I/O channel to new read or write operations; scheduling
 * operations on a closed channel results in their handler returning an error.
 *
 * If the DISPATCH_IO_STOP flag is provided, the system will make a best effort
 * to interrupt any outstanding read and write operations on the I/O channel,
 * otherwise those operations will run to completion normally.
 * Partial results of read and write operations may be returned even after a
 * channel is closed with the DISPATCH_IO_STOP flag.
 * The final invocation of an I/O handler of an interrupted operation will be
 * passed an ECANCELED error code, as will the I/O handler of an operation
 * scheduled on a closed channel.
 *
 * @param channel	The dispatch I/O channel to close.
 * @param flags		The flags for the close operation.
 */
API_AVAILABLE(macos(10.7), ios(5.0))
DISPATCH_EXPORT DISPATCH_NONNULL1 DISPATCH_NOTHROW
void
dispatch_io_close(dispatch_io_t channel, dispatch_io_close_flags_t flags);

#ifdef __BLOCKS__
/*!
 * @function dispatch_io_barrier
 * Schedule a barrier operation on the specified I/O channel; all previously
 * scheduled operations on the channel will complete before the provided
 * barrier block is enqueued onto the global queue determined by the channel's
 * target queue, and no subsequently scheduled operations will start until the
 * barrier block has returned.
 *
 * If multiple channels are associated with the same file descriptor, a barrier
 * operation scheduled on any of these channels will act as a barrier across all
 * channels in question, i.e. all previously scheduled operations on any of the
 * channels will complete before the barrier block is enqueued, and no
 * operations subsequently scheduled on any of the channels will start until the
 * barrier block has returned.
 *
 * While the barrier block is running, it may safely operate on the channel's
 * underlying file descriptor with fsync(2), lseek(2) etc. (but not close(2)).
 *
 * @param channel	The dispatch I/O channel to schedule the barrier on.
 * @param barrier	The barrier block.
 */
API_AVAILABLE(macos(10.7), ios(5.0))
DISPATCH_EXPORT DISPATCH_NONNULL_ALL DISPATCH_NOTHROW
void
dispatch_io_barrier(dispatch_io_t channel, dispatch_block_t barrier);
#endif /* __BLOCKS__ */

/*!
 * @function dispatch_io_get_descriptor
 * Returns the file descriptor underlying a dispatch I/O channel.
 *
 * Will return -1 for a channel closed with dispatch_io_close() and for a
 * channel associated with a path name that has not yet been open(2)ed.
 *
 * If called from a barrier block scheduled on a channel associated with a path
 * name that has not yet been open(2)ed, this will trigger the channel open(2)
 * operation and return the resulting file descriptor.
 *
 * @param channel	The dispatch I/O channel to query.
 * @result		The file descriptor underlying the channel, or -1.
 */
API_AVAILABLE(macos(10.7), ios(5.0))
DISPATCH_EXPORT DISPATCH_NONNULL_ALL DISPATCH_WARN_RESULT DISPATCH_NOTHROW
dispatch_fd_t
dispatch_io_get_descriptor(dispatch_io_t channel);

/*!
 * @function dispatch_io_set_high_water
 * Set a high water mark on the I/O channel for all operations.
 *
 * The system will make a best effort to enqueue I/O handlers with partial
 * results as soon the number of bytes processed by an operation (i.e. read or
 * written) reaches the high water mark.
 *
 * The size of data objects passed to I/O handlers for this channel will never
 * exceed the specified high water mark.
 *
 * The default value for the high water mark is unlimited (i.e. SIZE_MAX).
 *
 * @param channel	The dispatch I/O channel on which to set the policy.
 * @param high_water	The number of bytes to use as a high water mark.
 */
API_AVAILABLE(macos(10.7), ios(5.0))
DISPATCH_EXPORT DISPATCH_NONNULL1 DISPATCH_NOTHROW
void
dispatch_io_set_high_water(dispatch_io_t channel, size_t high_water);

/*!
 * @function dispatch_io_set_low_water
 * Set a low water mark on the I/O channel for all operations.
 *
 * The system will process (i.e. read or write) at least the low water mark
 * number of bytes for an operation before enqueueing I/O handlers with partial
 * results.
 *
 * The size of data objects passed to intermediate I/O handler invocations for
 * this channel (i.e. excluding the final invocation) will never be smaller than
 * the specified low water mark, except if the channel has an interval with the
 * DISPATCH_IO_STRICT_INTERVAL flag set or if EOF or an error was encountered.
 *
 * I/O handlers should be prepared to receive amounts of data significantly
 * larger than the low water mark in general. If an I/O handler requires
 * intermediate results of fixed size, set both the low and and the high water
 * mark to that size.
 *
 * The default value for the low water mark is unspecified, but must be assumed
 * to be such that intermediate handler invocations may occur.
 * If I/O handler invocations with partial results are not desired, set the
 * low water mark to SIZE_MAX.
 *
 * @param channel	The dispatch I/O channel on which to set the policy.
 * @param low_water	The number of bytes to use as a low water mark.
 */
API_AVAILABLE(macos(10.7), ios(5.0))
DISPATCH_EXPORT DISPATCH_NONNULL1 DISPATCH_NOTHROW
void
dispatch_io_set_low_water(dispatch_io_t channel, size_t low_water);

/*!
 * @typedef dispatch_io_interval_flags_t
 * Type of flags to set on dispatch_io_set_interval()
 *
 * @const DISPATCH_IO_STRICT_INTERVAL	Enqueue I/O handlers at a channel's
 * interval setting even if the amount of data ready to be delivered is inferior
 * to the low water mark (or zero).
 */
#define DISPATCH_IO_STRICT_INTERVAL 0x1

typedef unsigned long dispatch_io_interval_flags_t;

/*!
 * @function dispatch_io_set_interval
 * Set a nanosecond interval at which I/O handlers are to be enqueued on the
 * I/O channel for all operations.
 *
 * This allows an application to receive periodic feedback on the progress of
 * read and write operations, e.g. for the purposes of displaying progress bars.
 *
 * If the amount of data ready to be delivered to an I/O handler at the interval
 * is inferior to the channel low water mark, the handler will only be enqueued
 * if the DISPATCH_IO_STRICT_INTERVAL flag is set.
 *
 * Note that the system may defer enqueueing interval I/O handlers by a small
 * unspecified amount of leeway in order to align with other system activity for
 * improved system performance or power consumption.
 *
 * @param channel	The dispatch I/O channel on which to set the policy.
 * @param interval	The interval in nanoseconds at which delivery of the I/O
 *					handler is desired.
 * @param flags		Flags indicating desired data delivery behavior at
 *					interval time.
 */
API_AVAILABLE(macos(10.7), ios(5.0))
DISPATCH_EXPORT DISPATCH_NONNULL1 DISPATCH_NOTHROW
void
dispatch_io_set_interval(dispatch_io_t channel,
	uint64_t interval,
	dispatch_io_interval_flags_t flags);

__END_DECLS

DISPATCH_ASSUME_NONNULL_END

#endif /* __DISPATCH_IO__ */