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

#ifndef __DISPATCH_SOURCE__
#define __DISPATCH_SOURCE__

#ifndef __DISPATCH_INDIRECT__
#error "Please #include <dispatch/dispatch.h> instead of this file directly."
#include <dispatch/base.h> // for HeaderDoc
#endif

#if TARGET_OS_MAC
#include <mach/port.h>
#include <mach/message.h>
#endif

#if !defined(_WIN32)
#include <sys/signal.h>
#endif

DISPATCH_ASSUME_NONNULL_BEGIN
DISPATCH_ASSUME_ABI_SINGLE_BEGIN

/*!
 * @header
 * The dispatch framework provides a suite of interfaces for monitoring low-
 * level system objects (file descriptors, Mach ports, signals, VFS nodes, etc.)
 * for activity and automatically submitting event handler blocks to dispatch
 * queues when such activity occurs.
 *
 * This suite of interfaces is known as the Dispatch Source API.
 */

/*!
 * @typedef dispatch_source_t
 *
 * @abstract
 * Dispatch sources are used to automatically submit event handler blocks to
 * dispatch queues in response to external events.
 */
DISPATCH_SOURCE_DECL_SWIFT(dispatch_source, DispatchSource, DispatchSourceProtocol);

__BEGIN_DECLS

/*!
 * @typedef dispatch_source_type_t
 *
 * @abstract
 * Constants of this type represent the class of low-level system object that
 * is being monitored by the dispatch source. Constants of this type are
 * passed as a parameter to dispatch_source_create() and determine how the
 * handle argument is interpreted (i.e. as a file descriptor, mach port,
 * signal number, process identifier, etc.), and how the mask argument is
 * interpreted.
 */
DISPATCH_REFINED_FOR_SWIFT
typedef const struct dispatch_source_type_s *dispatch_source_type_t;

/*!
 * @const DISPATCH_SOURCE_TYPE_DATA_ADD
 * @discussion A dispatch source that coalesces data obtained via calls to
 * dispatch_source_merge_data(). An ADD is used to coalesce the data.
 * The handle is unused (pass zero for now).
 * The mask is unused (pass zero for now).
 */
#define DISPATCH_SOURCE_TYPE_DATA_ADD (&_dispatch_source_type_data_add)
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_SOURCE_TYPE_DECL_SWIFT(data_add, DispatchSourceUserDataAdd);

/*!
 * @const DISPATCH_SOURCE_TYPE_DATA_OR
 * @discussion A dispatch source that coalesces data obtained via calls to
 * dispatch_source_merge_data(). A bitwise OR is used to coalesce the data.
 * The handle is unused (pass zero for now).
 * The mask is unused (pass zero for now).
 */
#define DISPATCH_SOURCE_TYPE_DATA_OR (&_dispatch_source_type_data_or)
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_SOURCE_TYPE_DECL_SWIFT(data_or, DispatchSourceUserDataOr);

/*!
 * @const DISPATCH_SOURCE_TYPE_DATA_REPLACE
 * @discussion A dispatch source that tracks data obtained via calls to
 * dispatch_source_merge_data(). Newly obtained data values replace existing
 * data values not yet delivered to the source handler
 *
 * A data value of zero will cause the source handler to not be invoked.
 *
 * The handle is unused (pass zero for now).
 * The mask is unused (pass zero for now).
 */
#define DISPATCH_SOURCE_TYPE_DATA_REPLACE (&_dispatch_source_type_data_replace)
API_AVAILABLE(macos(10.13), ios(11.0), tvos(11.0), watchos(4.0))
DISPATCH_SOURCE_TYPE_DECL_SWIFT(data_replace, DispatchSourceUserDataReplace);

/*!
 * @const DISPATCH_SOURCE_TYPE_MACH_SEND
 * @discussion A dispatch source that monitors a Mach port for dead name
 * notifications (send right no longer has any corresponding receive right).
 * The handle is a Mach port with a send or send-once right (mach_port_t).
 * The mask is a mask of desired events from dispatch_source_mach_send_flags_t.
 */
#define DISPATCH_SOURCE_TYPE_MACH_SEND (&_dispatch_source_type_mach_send)
API_AVAILABLE(macos(10.6), ios(4.0)) DISPATCH_LINUX_UNAVAILABLE()
DISPATCH_SOURCE_TYPE_DECL_SWIFT(mach_send, DispatchSourceMachSend);

/*!
 * @const DISPATCH_SOURCE_TYPE_MACH_RECV
 * @discussion A dispatch source that monitors a Mach port for pending messages.
 * The handle is a Mach port with a receive right (mach_port_t).
 * The mask is a mask of desired events from dispatch_source_mach_recv_flags_t,
 * but no flags are currently defined (pass zero for now).
 */
#define DISPATCH_SOURCE_TYPE_MACH_RECV (&_dispatch_source_type_mach_recv)
API_AVAILABLE(macos(10.6), ios(4.0)) DISPATCH_LINUX_UNAVAILABLE()
DISPATCH_SOURCE_TYPE_DECL_SWIFT(mach_recv, DispatchSourceMachReceive);

/*!
 * @const DISPATCH_SOURCE_TYPE_MEMORYPRESSURE
 * @discussion A dispatch source that monitors the system for changes in
 * memory pressure condition.
 * The handle is unused (pass zero for now).
 * The mask is a mask of desired events from
 * dispatch_source_memorypressure_flags_t.
 */
#define DISPATCH_SOURCE_TYPE_MEMORYPRESSURE \
		(&_dispatch_source_type_memorypressure)
API_AVAILABLE(macos(10.9), ios(8.0)) DISPATCH_LINUX_UNAVAILABLE()
DISPATCH_SOURCE_TYPE_DECL_SWIFT(memorypressure, DispatchSourceMemoryPressure);

/*!
 * @const DISPATCH_SOURCE_TYPE_PROC
 * @discussion A dispatch source that monitors an external process for events
 * defined by dispatch_source_proc_flags_t.
 * The handle is a process identifier (pid_t).
 * The mask is a mask of desired events from dispatch_source_proc_flags_t.
 */
#define DISPATCH_SOURCE_TYPE_PROC (&_dispatch_source_type_proc)
API_AVAILABLE(macos(10.6), ios(4.0)) DISPATCH_LINUX_UNAVAILABLE()
DISPATCH_SOURCE_TYPE_DECL_SWIFT(proc, DispatchSourceProcess);

/*!
 * @const DISPATCH_SOURCE_TYPE_READ
 * @discussion A dispatch source that monitors a file descriptor for pending
 * bytes available to be read.
 * The handle is a file descriptor (int).
 * The mask is unused (pass zero for now).
 */
#define DISPATCH_SOURCE_TYPE_READ (&_dispatch_source_type_read)
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_SOURCE_TYPE_DECL_SWIFT(read, DispatchSourceRead);

/*!
 * @const DISPATCH_SOURCE_TYPE_SIGNAL
 * @discussion A dispatch source that monitors the current process for signals.
 * The handle is a signal number (int).
 * The mask is unused (pass zero for now).
 */
#define DISPATCH_SOURCE_TYPE_SIGNAL (&_dispatch_source_type_signal)
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_SOURCE_TYPE_DECL_SWIFT(signal, DispatchSourceSignal);

/*!
 * @const DISPATCH_SOURCE_TYPE_TIMER
 * @discussion A dispatch source that submits the event handler block based
 * on a timer.
 * The handle is unused (pass zero for now).
 * The mask specifies which flags from dispatch_source_timer_flags_t to apply.
 */
#define DISPATCH_SOURCE_TYPE_TIMER (&_dispatch_source_type_timer)
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_SOURCE_TYPE_DECL_SWIFT(timer, DispatchSourceTimer);

/*!
 * @const DISPATCH_SOURCE_TYPE_VNODE
 * @discussion A dispatch source that monitors a file descriptor for events
 * defined by dispatch_source_vnode_flags_t.
 * The handle is a file descriptor (int).
 * The mask is a mask of desired events from dispatch_source_vnode_flags_t.
 */
#define DISPATCH_SOURCE_TYPE_VNODE (&_dispatch_source_type_vnode)
API_AVAILABLE(macos(10.6), ios(4.0)) DISPATCH_LINUX_UNAVAILABLE()
DISPATCH_SOURCE_TYPE_DECL_SWIFT(vnode, DispatchSourceFileSystemObject);

/*!
 * @const DISPATCH_SOURCE_TYPE_WRITE
 * @discussion A dispatch source that monitors a file descriptor for available
 * buffer space to write bytes.
 * The handle is a file descriptor (int).
 * The mask is unused (pass zero for now).
 */
#define DISPATCH_SOURCE_TYPE_WRITE (&_dispatch_source_type_write)
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_SOURCE_TYPE_DECL_SWIFT(write, DispatchSourceWrite);

/*!
 * @typedef dispatch_source_mach_send_flags_t
 * Type of dispatch_source_mach_send flags
 *
 * @constant DISPATCH_MACH_SEND_DEAD
 * The receive right corresponding to the given send right was destroyed.
 */
#define DISPATCH_MACH_SEND_DEAD	0x1

DISPATCH_SWIFT_UNAVAILABLE("Use DispatchSource.MachSendEvent")
typedef unsigned long dispatch_source_mach_send_flags_t;

/*!
 * @typedef dispatch_source_mach_recv_flags_t
 * Type of dispatch_source_mach_recv flags
 */
typedef unsigned long dispatch_source_mach_recv_flags_t;

/*!
 * @typedef dispatch_source_memorypressure_flags_t
 * Type of dispatch_source_memorypressure flags
 *
 * @constant DISPATCH_MEMORYPRESSURE_NORMAL
 * The system memory pressure condition has returned to normal.
 *
 * @constant DISPATCH_MEMORYPRESSURE_WARN
 * The system memory pressure condition has changed to warning.
 *
 * @constant DISPATCH_MEMORYPRESSURE_CRITICAL
 * The system memory pressure condition has changed to critical.
 *
 * @discussion
 * Elevated memory pressure is a system-wide condition that applications
 * registered for this source should react to by changing their future memory
 * use behavior, e.g. by reducing cache sizes of newly initiated operations
 * until memory pressure returns back to normal.
 * NOTE: applications should NOT traverse and discard existing caches for past
 * operations when the system memory pressure enters an elevated state, as that
 * is likely to trigger VM operations that will further aggravate system memory
 * pressure.
 */

#define DISPATCH_MEMORYPRESSURE_NORMAL		0x01
#define DISPATCH_MEMORYPRESSURE_WARN		0x02
#define DISPATCH_MEMORYPRESSURE_CRITICAL	0x04

DISPATCH_SWIFT_UNAVAILABLE("Use DispatchSource.MemoryPressureEvent")
typedef unsigned long dispatch_source_memorypressure_flags_t;

/*!
 * @typedef dispatch_source_proc_flags_t
 * Type of dispatch_source_proc flags
 *
 * @constant DISPATCH_PROC_EXIT
 * The process has exited (perhaps cleanly, perhaps not).
 *
 * @constant DISPATCH_PROC_FORK
 * The process has created one or more child processes.
 *
 * @constant DISPATCH_PROC_EXEC
 * The process has become another executable image via
 * exec*() or posix_spawn*().
 *
 * @constant DISPATCH_PROC_SIGNAL
 * A Unix signal was delivered to the process.
 */
#define DISPATCH_PROC_EXIT		0x80000000
#define DISPATCH_PROC_FORK		0x40000000
#define DISPATCH_PROC_EXEC		0x20000000
#define DISPATCH_PROC_SIGNAL	0x08000000

DISPATCH_SWIFT_UNAVAILABLE("Use DispatchSource.ProcessEvent")
typedef unsigned long dispatch_source_proc_flags_t;

/*!
 * @typedef dispatch_source_vnode_flags_t
 * Type of dispatch_source_vnode flags
 *
 * @constant DISPATCH_VNODE_DELETE
 * The filesystem object was deleted from the namespace.
 *
 * @constant DISPATCH_VNODE_WRITE
 * The filesystem object data changed.
 *
 * @constant DISPATCH_VNODE_EXTEND
 * The filesystem object changed in size.
 *
 * @constant DISPATCH_VNODE_ATTRIB
 * The filesystem object metadata changed.
 *
 * @constant DISPATCH_VNODE_LINK
 * The filesystem object link count changed.
 *
 * @constant DISPATCH_VNODE_RENAME
 * The filesystem object was renamed in the namespace.
 *
 * @constant DISPATCH_VNODE_REVOKE
 * The filesystem object was revoked.
 *
 * @constant DISPATCH_VNODE_FUNLOCK
 * The filesystem object was unlocked.
 */

#define DISPATCH_VNODE_DELETE	0x1
#define DISPATCH_VNODE_WRITE	0x2
#define DISPATCH_VNODE_EXTEND	0x4
#define DISPATCH_VNODE_ATTRIB	0x8
#define DISPATCH_VNODE_LINK		0x10
#define DISPATCH_VNODE_RENAME	0x20
#define DISPATCH_VNODE_REVOKE	0x40
#define DISPATCH_VNODE_FUNLOCK	0x100

DISPATCH_SWIFT_UNAVAILABLE("Use DispatchSource.FileSystemEvent")
typedef unsigned long dispatch_source_vnode_flags_t;

/*!
 * @typedef dispatch_source_timer_flags_t
 * Type of dispatch_source_timer flags
 *
 * @constant DISPATCH_TIMER_STRICT
 * Specifies that the system should make a best effort to strictly observe the
 * leeway value specified for the timer via dispatch_source_set_timer(), even
 * if that value is smaller than the default leeway value that would be applied
 * to the timer otherwise. A minimal amount of leeway will be applied to the
 * timer even if this flag is specified.
 *
 * CAUTION: Use of this flag may override power-saving techniques employed by
 * the system and cause higher power consumption, so it must be used with care
 * and only when absolutely necessary.
 */

#define DISPATCH_TIMER_STRICT 0x1

DISPATCH_SWIFT_UNAVAILABLE("Use DispatchSource.TimerFlags")
typedef unsigned long dispatch_source_timer_flags_t;

/*!
 * @function dispatch_source_create
 *
 * @abstract
 * Creates a new dispatch source to monitor low-level system objects and auto-
 * matically submit a handler block to a dispatch queue in response to events.
 *
 * @discussion
 * Dispatch sources are not reentrant. Any events received while the dispatch
 * source is suspended or while the event handler block is currently executing
 * will be coalesced and delivered after the dispatch source is resumed or the
 * event handler block has returned.
 *
 * Dispatch sources are created in an inactive state. After creating the
 * source and setting any desired attributes (i.e. the handler, context, etc.),
 * a call must be made to dispatch_activate() in order to begin event delivery.
 *
 * A source must have been activated before being disposed.
 *
 * Calling dispatch_set_target_queue() on a source once it has been activated
 * is not allowed (see dispatch_activate() and dispatch_set_target_queue()).
 *
 * For backward compatibility reasons, dispatch_resume() on an inactive,
 * and not otherwise suspended source has the same effect as calling
 * dispatch_activate(). For new code, using dispatch_activate() is preferred.
 *
 * @param type
 * Declares the type of the dispatch source. Must be one of the defined
 * dispatch_source_type_t constants.
 *
 * @param handle
 * The underlying system handle to monitor. The interpretation of this argument
 * is determined by the constant provided in the type parameter.
 *
 * @param mask
 * A mask of flags specifying which events are desired. The interpretation of
 * this argument is determined by the constant provided in the type parameter.
 *
 * @param queue
 * The dispatch queue to which the event handler block will be submitted.
 * If queue is DISPATCH_TARGET_QUEUE_DEFAULT, the source will submit the event
 * handler block to the default priority global queue.
 *
 * @result
 * The newly created dispatch source. Or NULL if invalid arguments are passed.
 */
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_MALLOC DISPATCH_RETURNS_RETAINED DISPATCH_WARN_RESULT
DISPATCH_NOTHROW
DISPATCH_REFINED_FOR_SWIFT
dispatch_source_t
dispatch_source_create(dispatch_source_type_t type,
	uintptr_t handle,
	uintptr_t mask,
	dispatch_queue_t _Nullable queue);

/*!
 * @function dispatch_source_set_event_handler
 *
 * @abstract
 * Sets the event handler block for the given dispatch source.
 *
 * @param source
 * The dispatch source to modify.
 * The result of passing NULL in this parameter is undefined.
 *
 * @param handler
 * The event handler block to submit to the source's target queue.
 */
#ifdef __BLOCKS__
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_NONNULL1 DISPATCH_NOTHROW
DISPATCH_REFINED_FOR_SWIFT
void
dispatch_source_set_event_handler(dispatch_source_t source,
	dispatch_block_t _Nullable handler);
#endif /* __BLOCKS__ */

/*!
 * @function dispatch_source_set_event_handler_f
 *
 * @abstract
 * Sets the event handler function for the given dispatch source.
 *
 * @param source
 * The dispatch source to modify.
 * The result of passing NULL in this parameter is undefined.
 *
 * @param handler
 * The event handler function to submit to the source's target queue.
 * The context parameter passed to the event handler function is the context of
 * the dispatch source current at the time the event handler was set.
 */
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_NONNULL1 DISPATCH_NOTHROW
DISPATCH_SWIFT_UNAVAILABLE("DispatchSource.setEventHandler(self:handler:)")
void
dispatch_source_set_event_handler_f(dispatch_source_t source,
	dispatch_function_t _Nullable handler);

/*!
 * @function dispatch_source_set_cancel_handler
 *
 * @abstract
 * Sets the cancellation handler block for the given dispatch source.
 *
 * @discussion
 * The cancellation handler (if specified) will be submitted to the source's
 * target queue in response to a call to dispatch_source_cancel() once the
 * system has released all references to the source's underlying handle and
 * the source's event handler block has returned.
 *
 * IMPORTANT:
 * Source cancellation and a cancellation handler are required for file
 * descriptor and mach port based sources in order to safely close the
 * descriptor or destroy the port.
 * Closing the descriptor or port before the cancellation handler is invoked may
 * result in a race condition. If a new descriptor is allocated with the same
 * value as the recently closed descriptor while the source's event handler is
 * still running, the event handler may read/write data to the wrong descriptor.
 *
 * @param source
 * The dispatch source to modify.
 * The result of passing NULL in this parameter is undefined.
 *
 * @param handler
 * The cancellation handler block to submit to the source's target queue.
 */
#ifdef __BLOCKS__
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_NONNULL1 DISPATCH_NOTHROW
DISPATCH_REFINED_FOR_SWIFT
void
dispatch_source_set_cancel_handler(dispatch_source_t source,
	dispatch_block_t _Nullable handler);
#endif /* __BLOCKS__ */

/*!
 * @function dispatch_source_set_cancel_handler_f
 *
 * @abstract
 * Sets the cancellation handler function for the given dispatch source.
 *
 * @discussion
 * See dispatch_source_set_cancel_handler() for more details.
 *
 * @param source
 * The dispatch source to modify.
 * The result of passing NULL in this parameter is undefined.
 *
 * @param handler
 * The cancellation handler function to submit to the source's target queue.
 * The context parameter passed to the event handler function is the current
 * context of the dispatch source at the time the handler call is made.
 */
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_NONNULL1 DISPATCH_NOTHROW
DISPATCH_SWIFT_UNAVAILABLE("Use DispatchSource.setCancelHandler(self:handler:)")
void
dispatch_source_set_cancel_handler_f(dispatch_source_t source,
	dispatch_function_t _Nullable handler);

/*!
 * @function dispatch_source_cancel
 *
 * @abstract
 * Asynchronously cancel the dispatch source, preventing any further invocation
 * of its event handler block.
 *
 * @discussion
 * Cancellation prevents any further invocation of the event handler block for
 * the specified dispatch source, but does not interrupt an event handler
 * block that is already in progress.
 *
 * The cancellation handler is submitted to the source's target queue once the
 * the source's event handler has finished, indicating it is now safe to close
 * the source's handle (i.e. file descriptor or mach port).
 *
 * See dispatch_source_set_cancel_handler() for more information.
 *
 * @param source
 * The dispatch source to be canceled.
 * The result of passing NULL in this parameter is undefined.
 */
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_NONNULL_ALL DISPATCH_NOTHROW
DISPATCH_REFINED_FOR_SWIFT
void
dispatch_source_cancel(dispatch_source_t source);

/*!
 * @function dispatch_source_testcancel
 *
 * @abstract
 * Tests whether the given dispatch source has been canceled.
 *
 * @param source
 * The dispatch source to be tested.
 * The result of passing NULL in this parameter is undefined.
 *
 * @result
 * Non-zero if canceled and zero if not canceled.
 */
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_NONNULL_ALL DISPATCH_WARN_RESULT DISPATCH_PURE
DISPATCH_NOTHROW
DISPATCH_REFINED_FOR_SWIFT
intptr_t
dispatch_source_testcancel(dispatch_source_t source);

/*!
 * @function dispatch_source_get_handle
 *
 * @abstract
 * Returns the underlying system handle associated with this dispatch source.
 *
 * @param source
 * The result of passing NULL in this parameter is undefined.
 *
 * @result
 * The return value should be interpreted according to the type of the dispatch
 * source, and may be one of the following handles:
 *
 *  DISPATCH_SOURCE_TYPE_DATA_ADD:        n/a
 *  DISPATCH_SOURCE_TYPE_DATA_OR:         n/a
 *  DISPATCH_SOURCE_TYPE_DATA_REPLACE:    n/a
 *  DISPATCH_SOURCE_TYPE_MACH_SEND:       mach port (mach_port_t)
 *  DISPATCH_SOURCE_TYPE_MACH_RECV:       mach port (mach_port_t)
 *  DISPATCH_SOURCE_TYPE_MEMORYPRESSURE   n/a
 *  DISPATCH_SOURCE_TYPE_PROC:            process identifier (pid_t)
 *  DISPATCH_SOURCE_TYPE_READ:            file descriptor (int)
 *  DISPATCH_SOURCE_TYPE_SIGNAL:          signal number (int)
 *  DISPATCH_SOURCE_TYPE_TIMER:           n/a
 *  DISPATCH_SOURCE_TYPE_VNODE:           file descriptor (int)
 *  DISPATCH_SOURCE_TYPE_WRITE:           file descriptor (int)
 */
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_NONNULL_ALL DISPATCH_WARN_RESULT DISPATCH_PURE
DISPATCH_NOTHROW
DISPATCH_REFINED_FOR_SWIFT
uintptr_t
dispatch_source_get_handle(dispatch_source_t source);

/*!
 * @function dispatch_source_get_mask
 *
 * @abstract
 * Returns the mask of events monitored by the dispatch source.
 *
 * @param source
 * The result of passing NULL in this parameter is undefined.
 *
 * @result
 * The return value should be interpreted according to the type of the dispatch
 * source, and may be one of the following flag sets:
 *
 *  DISPATCH_SOURCE_TYPE_DATA_ADD:        n/a
 *  DISPATCH_SOURCE_TYPE_DATA_OR:         n/a
 *  DISPATCH_SOURCE_TYPE_DATA_REPLACE:    n/a
 *  DISPATCH_SOURCE_TYPE_MACH_SEND:       dispatch_source_mach_send_flags_t
 *  DISPATCH_SOURCE_TYPE_MACH_RECV:       dispatch_source_mach_recv_flags_t
 *  DISPATCH_SOURCE_TYPE_MEMORYPRESSURE   dispatch_source_memorypressure_flags_t
 *  DISPATCH_SOURCE_TYPE_PROC:            dispatch_source_proc_flags_t
 *  DISPATCH_SOURCE_TYPE_READ:            n/a
 *  DISPATCH_SOURCE_TYPE_SIGNAL:          n/a
 *  DISPATCH_SOURCE_TYPE_TIMER:           dispatch_source_timer_flags_t
 *  DISPATCH_SOURCE_TYPE_VNODE:           dispatch_source_vnode_flags_t
 *  DISPATCH_SOURCE_TYPE_WRITE:           n/a
 */
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_NONNULL_ALL DISPATCH_WARN_RESULT DISPATCH_PURE
DISPATCH_NOTHROW
DISPATCH_REFINED_FOR_SWIFT
uintptr_t
dispatch_source_get_mask(dispatch_source_t source);

/*!
 * @function dispatch_source_get_data
 *
 * @abstract
 * Returns pending data for the dispatch source.
 *
 * @discussion
 * This function is intended to be called from within the event handler block.
 * The result of calling this function outside of the event handler callback is
 * undefined.
 *
 * @param source
 * The result of passing NULL in this parameter is undefined.
 *
 * @result
 * The return value should be interpreted according to the type of the dispatch
 * source, and may be one of the following:
 *
 *  DISPATCH_SOURCE_TYPE_DATA_ADD:        application defined data
 *  DISPATCH_SOURCE_TYPE_DATA_OR:         application defined data
 *  DISPATCH_SOURCE_TYPE_DATA_REPLACE:    application defined data
 *  DISPATCH_SOURCE_TYPE_MACH_SEND:       dispatch_source_mach_send_flags_t
 *  DISPATCH_SOURCE_TYPE_MACH_RECV:       dispatch_source_mach_recv_flags_t
 *  DISPATCH_SOURCE_TYPE_MEMORYPRESSURE   dispatch_source_memorypressure_flags_t
 *  DISPATCH_SOURCE_TYPE_PROC:            dispatch_source_proc_flags_t
 *  DISPATCH_SOURCE_TYPE_READ:            estimated bytes available to read
 *  DISPATCH_SOURCE_TYPE_SIGNAL:          number of signals delivered since
 *                                            the last handler invocation
 *  DISPATCH_SOURCE_TYPE_TIMER:           number of times the timer has fired
 *                                            since the last handler invocation
 *  DISPATCH_SOURCE_TYPE_VNODE:           dispatch_source_vnode_flags_t
 *  DISPATCH_SOURCE_TYPE_WRITE:           estimated buffer space available
 */
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_NONNULL_ALL DISPATCH_WARN_RESULT DISPATCH_PURE
DISPATCH_NOTHROW
DISPATCH_REFINED_FOR_SWIFT
uintptr_t
dispatch_source_get_data(dispatch_source_t source);

/*!
 * @function dispatch_source_merge_data
 *
 * @abstract
 * Merges data into a dispatch source of type DISPATCH_SOURCE_TYPE_DATA_ADD,
 * DISPATCH_SOURCE_TYPE_DATA_OR or DISPATCH_SOURCE_TYPE_DATA_REPLACE,
 * and submits its event handler block to its target queue.
 *
 * @param source
 * The result of passing NULL in this parameter is undefined.
 *
 * @param value
 * The value to coalesce with the pending data using a logical OR or an ADD
 * as specified by the dispatch source type. A value of zero has no effect
 * and will not result in the submission of the event handler block.
 */
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_NONNULL_ALL DISPATCH_NOTHROW
DISPATCH_REFINED_FOR_SWIFT
void
dispatch_source_merge_data(dispatch_source_t source, uintptr_t value);

/*!
 * @function dispatch_source_set_timer
 *
 * @abstract
 * Sets a start time, interval, and leeway value for a timer source.
 *
 * @discussion
 * Once this function returns, any pending source data accumulated for the
 * previous timer values has been cleared; the next fire of the timer will
 * occur at 'start', and every 'interval' nanoseconds thereafter until the
 * timer source is canceled.
 *
 * Any fire of the timer may be delayed by the system in order to improve power
 * consumption and system performance. The upper limit to the allowable delay
 * may be configured with the 'leeway' argument, the lower limit is under the
 * control of the system.
 *
 * For the initial timer fire at 'start', the upper limit to the allowable
 * delay is set to 'leeway' nanoseconds. For the subsequent timer fires at
 * 'start' + N * 'interval', the upper limit is MIN('leeway','interval'/2).
 *
 * The lower limit to the allowable delay may vary with process state such as
 * visibility of application UI. If the specified timer source was created with
 * a mask of DISPATCH_TIMER_STRICT, the system will make a best effort to
 * strictly observe the provided 'leeway' value even if it is smaller than the
 * current lower limit. Note that a minimal amount of delay is to be expected
 * even if this flag is specified.
 *
 * The 'start' argument also determines which clock will be used for the timer:
 * If 'start' is DISPATCH_TIME_NOW or was created with dispatch_time(3), the
 * timer is based on up time (which is obtained from mach_absolute_time() on
 * Apple platforms). If 'start' was created with dispatch_walltime(3), the
 * timer is based on gettimeofday(3).
 *
 * Calling this function has no effect if the timer source has already been
 * canceled.
 *
 * @param start
 * The start time of the timer. See dispatch_time() and dispatch_walltime()
 * for more information.
 *
 * @param interval
 * The nanosecond interval for the timer. Use DISPATCH_TIME_FOREVER for a
 * one-shot timer.
 *
 * @param leeway
 * The nanosecond leeway for the timer.
 */
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_NONNULL_ALL DISPATCH_NOTHROW
DISPATCH_REFINED_FOR_SWIFT
void
dispatch_source_set_timer(dispatch_source_t source,
	dispatch_time_t start,
	uint64_t interval,
	uint64_t leeway);

/*!
 * @function dispatch_source_set_registration_handler
 *
 * @abstract
 * Sets the registration handler block for the given dispatch source.
 *
 * @discussion
 * The registration handler (if specified) will be submitted to the source's
 * target queue once the corresponding kevent() has been registered with the
 * system, following the initial dispatch_resume() of the source.
 *
 * If a source is already registered when the registration handler is set, the
 * registration handler will be invoked immediately.
 *
 * @param source
 * The dispatch source to modify.
 * The result of passing NULL in this parameter is undefined.
 *
 * @param handler
 * The registration handler block to submit to the source's target queue.
 */
#ifdef __BLOCKS__
API_AVAILABLE(macos(10.7), ios(4.3))
DISPATCH_EXPORT DISPATCH_NONNULL1 DISPATCH_NOTHROW
DISPATCH_REFINED_FOR_SWIFT
void
dispatch_source_set_registration_handler(dispatch_source_t source,
	dispatch_block_t _Nullable handler);
#endif /* __BLOCKS__ */

/*!
 * @function dispatch_source_set_registration_handler_f
 *
 * @abstract
 * Sets the registration handler function for the given dispatch source.
 *
 * @discussion
 * See dispatch_source_set_registration_handler() for more details.
 *
 * @param source
 * The dispatch source to modify.
 * The result of passing NULL in this parameter is undefined.
 *
 * @param handler
 * The registration handler function to submit to the source's target queue.
 * The context parameter passed to the registration handler function is the
 * current context of the dispatch source at the time the handler call is made.
 */
API_AVAILABLE(macos(10.7), ios(4.3))
DISPATCH_EXPORT DISPATCH_NONNULL1 DISPATCH_NOTHROW
DISPATCH_SWIFT_UNAVAILABLE("Use DispatchSource.setRegistrationHandler(self:handler:)")
void
dispatch_source_set_registration_handler_f(dispatch_source_t source,
	dispatch_function_t _Nullable handler);

__END_DECLS

DISPATCH_ASSUME_ABI_SINGLE_END
DISPATCH_ASSUME_NONNULL_END

#endif
