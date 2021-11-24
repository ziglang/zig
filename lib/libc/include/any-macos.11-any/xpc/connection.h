#ifndef __XPC_CONNECTION_H__
#define __XPC_CONNECTION_H__

#ifndef __XPC_INDIRECT__
#error "Please #include <xpc/xpc.h> instead of this file directly."
// For HeaderDoc.
#include <xpc/base.h>
#endif // __XPC_INDIRECT__

#ifndef __BLOCKS__
#error "XPC connections require Blocks support."
#endif // __BLOCKS__

XPC_ASSUME_NONNULL_BEGIN
__BEGIN_DECLS

/*!
 * @constant XPC_ERROR_CONNECTION_INTERRUPTED
 * Will be delivered to the connection's event handler if the remote service
 * exited. The connection is still live even in this case, and resending a
 * message will cause the service to be launched on-demand. This error serves
 * as a client's indication that it should resynchronize any state that it had
 * given the service.
 *
 * Any messages in the queue to be sent will be unwound and canceled when this
 * error occurs. In the case where a message waiting to be sent has a reply
 * handler, that handler will be invoked with this error. In the context of the
 * reply handler, this error indicates that a reply to the message will never
 * arrive.
 *
 * Messages that do not have reply handlers associated with them will be
 * silently disposed of. This error will only be given to peer connections.
 */
#define XPC_ERROR_CONNECTION_INTERRUPTED \
	XPC_GLOBAL_OBJECT(_xpc_error_connection_interrupted)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
const struct _xpc_dictionary_s _xpc_error_connection_interrupted;

/*!
 * @constant XPC_ERROR_CONNECTION_INVALID
 * Will be delivered to the connection's event handler if the named service
 * provided to xpc_connection_create() could not be found in the XPC service
 * namespace. The connection is useless and should be disposed of.
 *
 * Any messages in the queue to be sent will be unwound and canceled when this
 * error occurs, similarly to the behavior when XPC_ERROR_CONNECTION_INTERRUPTED
 * occurs. The only difference is that the XPC_ERROR_CONNECTION_INVALID will be
 * given to outstanding reply handlers and the connection's event handler.
 *
 * This error may be given to any type of connection.
 */
#define XPC_ERROR_CONNECTION_INVALID \
	XPC_GLOBAL_OBJECT(_xpc_error_connection_invalid)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
const struct _xpc_dictionary_s _xpc_error_connection_invalid;

/*!
 * @constant XPC_ERROR_TERMINATION_IMMINENT
 * On macOS, this error will be delivered to a peer connection's event handler
 * when the XPC runtime has determined that the program should exit and that
 * all outstanding transactions must be wound down, and no new transactions can
 * be opened.
 *
 * After this error has been delivered to the event handler, no more messages
 * will be received by the connection. The runtime will still attempt to deliver
 * outgoing messages, but this error should be treated as an indication that
 * the program will exit very soon, and any outstanding business over the
 * connection should be wrapped up as quickly as possible and the connection
 * canceled shortly thereafter.
 *
 * This error will only be delivered to peer connections received through a
 * listener or the xpc_main() event handler.
 */
#define XPC_ERROR_TERMINATION_IMMINENT \
	XPC_GLOBAL_OBJECT(_xpc_error_termination_imminent)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
const struct _xpc_dictionary_s _xpc_error_termination_imminent;

/*!
 * @constant XPC_CONNECTION_MACH_SERVICE_LISTENER
 * Passed to xpc_connection_create_mach_service(). This flag indicates that the
 * caller is the listener for the named service. This flag may only be passed
 * for services which are advertised in the process' launchd.plist(5). You may
 * not use this flag to dynamically add services to the Mach bootstrap
 * namespace.
 */
#define XPC_CONNECTION_MACH_SERVICE_LISTENER (1 << 0)

/*!
 * @constant XPC_CONNECTION_MACH_SERVICE_PRIVILEGED
 * Passed to xpc_connection_create_mach_service(). This flag indicates that the
 * job advertising the service name in its launchd.plist(5) should be in the
 * privileged Mach bootstrap. This is typically accomplished by placing your
 * launchd.plist(5) in /Library/LaunchDaemons. If specified alongside the
 * XPC_CONNECTION_MACH_SERVICE_LISTENER flag, this flag is a no-op.
 */
#define XPC_CONNECTION_MACH_SERVICE_PRIVILEGED (1 << 1)

/*!
 * @typedef xpc_finalizer_f
 * A function that is invoked when a connection is being torn down and its
 * context needs to be freed. The sole argument is the value that was given to
 * {@link xpc_connection_set_context} or NULL if no context has been set. It is
 * not safe to reference the connection from within this function.
 *
 * @param value
 * The context object that is to be disposed of.
 */
typedef void (*xpc_finalizer_t)(void * _Nullable value);

/*!
 * @function xpc_connection_create
 * Creates a new connection object.
 *
 * @param name
 * If non-NULL, the name of the service with which to connect. The returned
 * connection will be a peer.
 *
 * If NULL, an anonymous listener connection will be created. You can embed the
 * ability to create new peer connections in an endpoint, which can be inserted
 * into a message and sent to another process .
 *
 * @param targetq
 * The GCD queue to which the event handler block will be submitted. This
 * parameter may be NULL, in which case the connection's target queue will be
 * libdispatch's default target queue, defined as DISPATCH_TARGET_QUEUE_DEFAULT.
 * The target queue may be changed later with a call to
 * xpc_connection_set_target_queue().
 *
 * @result
 * A new connection object. The caller is responsible for disposing of the
 * returned object with {@link xpc_release} when it is no longer needed.
 *
 * @discussion
 * This method will succeed even if the named service does not exist. This is
 * because the XPC namespace is not queried for the service name until the
 * connection has been activated. See {@link xpc_connection_activate()}.
 *
 * XPC connections, like dispatch sources, are returned in an inactive state, so
 * you must call {@link xpc_connection_activate()} in order to begin receiving
 * events from the connection. Also like dispatch sources, connections must be
 * activated and not suspended in order to be safely released. It is
 * a programming error to release an inactive or suspended connection.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_connection_t
xpc_connection_create(const char * _Nullable name,
	dispatch_queue_t _Nullable targetq);

/*!
 * @function xpc_connection_create_mach_service
 * Creates a new connection object representing a Mach service.
 *
 * @param name
 * The name of the remote service with which to connect. The service name must
 * exist in a Mach bootstrap that is accessible to the process and be advertised
 * in a launchd.plist.
 *
 * @param targetq
 * The GCD queue to which the event handler block will be submitted. This
 * parameter may be NULL, in which case the connection's target queue will be
 * libdispatch's default target queue, defined as DISPATCH_TARGET_QUEUE_DEFAULT.
 * The target queue may be changed later with a call to
 * xpc_connection_set_target_queue().
 *
 * @param flags
 * Additional attributes with which to create the connection.
 *
 * @result
 * A new connection object.
 *
 * @discussion
 * If the XPC_CONNECTION_MACH_SERVICE_LISTENER flag is given to this method,
 * then the connection returned will be a listener connection. Otherwise, a peer
 * connection will be returned. See the documentation for
 * {@link xpc_connection_set_event_handler()} for the semantics of listener
 * connections versus peer connections.
 *
 * This method will succeed even if the named service does not exist. This is
 * because the Mach namespace is not queried for the service name until the
 * connection has been activated. See {@link xpc_connection_activate()}.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT XPC_NONNULL1
xpc_connection_t
xpc_connection_create_mach_service(const char *name,
	dispatch_queue_t _Nullable targetq, uint64_t flags);

/*!
 * @function xpc_connection_create_from_endpoint
 * Creates a new connection from the given endpoint.
 *
 * @param endpoint
 * The endpoint from which to create the new connection.
 *
 * @result
 * A new peer connection to the listener represented by the given endpoint.
 *
 * The same responsibilities of setting an event handler and activating the
 * connection after calling xpc_connection_create() apply to the connection
 * returned by this API. Since the connection yielded by this API is not
 * associated with a name (and therefore is not rediscoverable), this connection
 * will receive XPC_ERROR_CONNECTION_INVALID if the listening side crashes,
 * exits or cancels the listener connection.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT XPC_NONNULL_ALL
xpc_connection_t
xpc_connection_create_from_endpoint(xpc_endpoint_t endpoint);

/*!
 * @function xpc_connection_set_target_queue
 * Sets the target queue of the given connection.
 *
 * @param connection
 * The connection object which is to be manipulated.
 *
 * @param targetq
 * The GCD queue to which the event handler block will be submitted. This
 * parameter may be NULL, in which case the connection's target queue will be
 * libdispatch's default target queue, defined as DISPATCH_TARGET_QUEUE_DEFAULT.
 *
 * @discussion
 * Setting the target queue is asynchronous and non-preemptive and therefore
 * this method will not interrupt the execution of an already-running event
 * handler block. Setting the target queue may be likened to issuing a barrier
 * to the connection which does the actual work of changing the target queue.
 *
 * The XPC runtime guarantees this non-preemptiveness even for concurrent target
 * queues. If the target queue is a concurrent queue, then XPC still guarantees
 * that there will never be more than one invocation of the connection's event
 * handler block executing concurrently. If you wish to process events
 * concurrently, you can dispatch_async(3) to a concurrent queue from within
 * the event handler.
 *
 * IMPORTANT: When called from within the event handler block,
 * dispatch_get_current_queue(3) is NOT guaranteed to return a pointer to the
 * queue set with this method.
 *
 * Despite this seeming inconsistency, the XPC runtime guarantees that, when the
 * target queue is a serial queue, the event handler block will execute
 * synchonously with respect to other blocks submitted to that same queue. When
 * the target queue is a concurrent queue, the event handler block may run
 * concurrently with other blocks submitted to that queue, but it will never run
 * concurrently with other invocations of itself for the same connection, as
 * discussed previously.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
void
xpc_connection_set_target_queue(xpc_connection_t connection,
	dispatch_queue_t _Nullable targetq);

/*!
 * @function xpc_connection_set_event_handler
 * Sets the event handler block for the connection.
 *
 * @param connection
 * The connection object which is to be manipulated.
 *
 * @param handler
 * The event handler block.
 *
 * @discussion
 * Setting the event handler is asynchronous and non-preemptive, and therefore
 * this method will not interrupt the execution of an already-running event
 * handler block. If the event handler is executing at the time of this call, it
 * will finish, and then the connection's event handler will be changed before
 * the next invocation of the event handler. The XPC runtime guarantees this
 * non-preemptiveness even for concurrent target queues.
 *
 * Connection event handlers are non-reentrant, so it is safe to call
 * xpc_connection_set_event_handler() from within the event handler block.
 *
 * The event handler's execution should be treated as a barrier to all
 * connection activity. When it is executing, the connection will not attempt to
 * send or receive messages, including reply messages. Thus, it is not safe to
 * call xpc_connection_send_message_with_reply_sync() on the connection from
 * within the event handler.
 *
 * You do not hold a reference on the object received as the event handler's
 * only argument. Regardless of the type of object received, it is safe to call
 * xpc_retain() on the object to obtain a reference to it.
 *
 * A connection may receive different events depending upon whether it is a
 * listener or not. Any connection may receive an error in its event handler.
 * But while normal connections may receive messages in addition to errors,
 * listener connections will receive connections and and not messages.
 *
 * Connections received by listeners are equivalent to those returned by
 * xpc_connection_create() with a non-NULL name argument and a NULL targetq
 * argument with the exception that you do not hold a reference on them.
 * You must set an event handler and activate the connection. If you do not wish
 * to accept the connection, you may simply call xpc_connection_cancel() on it
 * and return. The runtime will dispose of it for you.
 *
 * If there is an error in the connection, this handler will be invoked with the
 * error dictionary as its argument. This dictionary will be one of the well-
 * known XPC_ERROR_* dictionaries.
 *
 * Regardless of the type of event, ownership of the event object is NOT
 * implicitly transferred. Thus, the object will be released and deallocated at
 * some point in the future after the event handler returns. If you wish the
 * event's lifetime to persist, you must retain it with xpc_retain().
 *
 * Connections received through the event handler will be released and
 * deallocated after the connection has gone invalid and delivered that event to
 * its event handler.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL
void
xpc_connection_set_event_handler(xpc_connection_t connection,
	xpc_handler_t handler);

/*!
 * @function xpc_connection_activate
 * Activates the connection. Connections start in an inactive state, so you must
 * call xpc_connection_activate() on a connection before it will send or receive
 * any messages.
 *
 * @param connection
 * The connection object which is to be manipulated.
 *
 * @discussion
 * Calling xpc_connection_activate() on an active connection has no effect.
 * Releasing the last reference on an inactive connection that was created with
 * an xpc_connection_create*() call is undefined.
 *
 * For backward compatibility reasons, xpc_connection_resume() on an inactive
 * and not otherwise suspended xpc connection has the same effect as calling
 * xpc_connection_activate(). For new code, using xpc_connection_activate()
 * is preferred.
 */
__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0)
__TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0)
XPC_EXPORT XPC_NONNULL_ALL
void
xpc_connection_activate(xpc_connection_t connection);

/*!
 * @function xpc_connection_suspend
 * Suspends the connection so that the event handler block will not fire and
 * that the connection will not attempt to send any messages it has in its
 * queue. All calls to xpc_connection_suspend() must be balanced with calls to
 * xpc_connection_resume() before releasing the last reference to the
 * connection.
 *
 * @param connection
 * The connection object which is to be manipulated.
 *
 * @discussion
 * Suspension is asynchronous and non-preemptive, and therefore this method will
 * not interrupt the execution of an already-running event handler block. If
 * the event handler is executing at the time of this call, it will finish, and
 * then the connection will be suspended before the next scheduled invocation
 * of the event handler. The XPC runtime guarantees this non-preemptiveness even
 * for concurrent target queues.
 *
 * Connection event handlers are non-reentrant, so it is safe to call
 * xpc_connection_suspend() from within the event handler block.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL
void
xpc_connection_suspend(xpc_connection_t connection);

/*!
 * @function xpc_connection_resume
 * Resumes the connection.
 *
 * @param connection
 * The connection object which is to be manipulated.
 *
 * @discussion
 * In order for a connection to become live, every call to
 * xpc_connection_suspend() must be balanced with a call to
 * xpc_connection_resume().
 *
 * For backward compatibility reasons, xpc_connection_resume() on an inactive
 * and not otherwise suspended xpc connection has the same effect as calling
 * xpc_connection_activate(). For new code, using xpc_connection_activate()
 * is preferred.
 *
 * Calling xpc_connection_resume() more times than xpc_connection_suspend()
 * has been called is otherwise considered an error.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL
void
xpc_connection_resume(xpc_connection_t connection);

/*!
 * @function xpc_connection_send_message
 * Sends a message over the connection to the destination service.
 *
 * @param connection
 * The connection over which the message shall be sent.
 *
 * @param message
 * The message to send. This must be a dictionary object. This dictionary is
 * logically copied by the connection, so it is safe to modify the dictionary
 * after this call.
 *
 * @discussion
 * Messages are delivered in FIFO order. This API is safe to call from multiple
 * GCD queues. There is no indication that a message was delivered successfully.
 * This is because even once the message has been successfully enqueued on the
 * remote end, there are no guarantees about when the runtime will dequeue the
 * message and invoke the other connection's event handler block.
 *
 * If this API is used to send a message that is in reply to another message,
 * there is no guarantee of ordering between the invocations of the connection's
 * event handler and the reply handler for that message, even if they are
 * targeted to the same queue.
 *
 * After extensive study, we have found that clients who are interested in
 * the state of the message on the server end are typically holding open
 * transactions related to that message. And the only reliable way to track the
 * lifetime of that transaction is at the protocol layer. So the server should
 * send a reply message, which upon receiving, will cause the client to close
 * its transaction.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL
void
xpc_connection_send_message(xpc_connection_t connection, xpc_object_t message);

/*!
 * @function xpc_connection_send_barrier
 * Issues a barrier against the connection's message-send activity.
 *
 * @param connection
 * The connection against which the barrier is to be issued.
 *
 * @param barrier
 * The barrier block to issue. This barrier prevents concurrent message-send
 * activity on the connection. No messages will be sent while the barrier block
 * is executing.
 *
 * @discussion
 * XPC guarantees that, even if the connection's target queue is a concurrent
 * queue, there are no other messages being sent concurrently while the barrier
 * block is executing. XPC does not guarantee that the receipt of messages
 * (either through the connection's event handler or through reply handlers)
 * will be suspended while the barrier is executing.
 *
 * A barrier is issued relative to the message-send queue. Thus, if you call
 * xpc_connection_send_message() five times and then call
 * xpc_connection_send_barrier(), the barrier will be invoked after the fifth
 * message has been sent and its memory disposed of. You may safely cancel a
 * connection from within a barrier block.
 *
 * If a barrier is issued after sending a message which expects a reply, the
 * behavior is the same as described above. The receipt of a reply message will
 * not influence when the barrier runs.
 *
 * A barrier block can be useful for throttling resource consumption on the
 * connected side of a connection. For example, if your connection sends many
 * large messages, you can use a barrier to limit the number of messages that
 * are inflight at any given time. This can be particularly useful for messages
 * that contain kernel resources (like file descriptors) which have a system-
 * wide limit.
 *
 * If a barrier is issued on a canceled connection, it will be invoked
 * immediately. If a connection has been canceled and still has outstanding
 * barriers, those barriers will be invoked as part of the connection's
 * unwinding process.
 *
 * It is important to note that a barrier block's execution order is not
 * guaranteed with respect to other blocks that have been scheduled on the
 * target queue of the connection. Or said differently,
 * xpc_connection_send_barrier(3) is not equivalent to dispatch_async(3).
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL
void
xpc_connection_send_barrier(xpc_connection_t connection,
	dispatch_block_t barrier);

/*!
 * @function xpc_connection_send_message_with_reply
 * Sends a message over the connection to the destination service and associates
 * a handler to be invoked when the remote service sends a reply message.
 *
 * @param connection
 * The connection over which the message shall be sent.
 *
 * @param message
 * The message to send. This must be a dictionary object.
 *
 * @param replyq
 * The GCD queue to which the reply handler will be submitted. This may be a
 * concurrent queue.
 *
 * @param handler
 * The handler block to invoke when a reply to the message is received from
 * the connection. If the remote service exits prematurely before the reply was
 * received, the XPC_ERROR_CONNECTION_INTERRUPTED error will be returned.
 * If the connection went invalid before the message could be sent, the
 * XPC_ERROR_CONNECTION_INVALID error will be returned.
 *
 * @discussion
 * If the given GCD queue is a concurrent queue, XPC cannot guarantee that there
 * will not be multiple reply handlers being invoked concurrently. XPC does not
 * guarantee any ordering for the invocation of reply handers. So if multiple
 * messages are waiting for replies and the connection goes invalid, there is no
 * guarantee that the reply handlers will be invoked in FIFO order. Similarly,
 * XPC does not guarantee that reply handlers will not run concurrently with
 * the connection's event handler in the case that the reply queue and the
 * connection's target queue are the same concurrent queue.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2 XPC_NONNULL4
void
xpc_connection_send_message_with_reply(xpc_connection_t connection,
	xpc_object_t message, dispatch_queue_t _Nullable replyq,
	xpc_handler_t handler);

/*!
 * @function xpc_connection_send_message_with_reply_sync
 * Sends a message over the connection and blocks the caller until a reply is
 * received.
 *
 * @param connection
 * The connection over which the message shall be sent.
 *
 * @param message
 * The message to send. This must be a dictionary object.
 *
 * @result
 * The message that the remote service sent in reply to the original message.
 * If the remote service exits prematurely before the reply was received, the
 * XPC_ERROR_CONNECTION_INTERRUPTED error will be returned. If the connection
 * went invalid before the message could be sent, the
 * XPC_ERROR_CONNECTION_INVALID error will be returned.
 *
 * You are responsible for releasing the returned object.
 *
 * @discussion
 * This API supports priority inversion avoidance, and should be used instead of
 * combining xpc_connection_send_message_with_reply() with a semaphore.
 *
 * Invoking this API from a queue that is a part of the target queue hierarchy
 * results in deadlocks under certain conditions.
 *
 * Be judicious about your use of this API. It can block indefinitely, so if you
 * are using it to implement an API that can be called from the main thread, you
 * may wish to consider allowing the API to take a queue and callback block so
 * that results may be delivered asynchronously if possible.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT XPC_RETURNS_RETAINED
xpc_object_t
xpc_connection_send_message_with_reply_sync(xpc_connection_t connection,
	xpc_object_t message);

/*!
 * @function xpc_connection_cancel
 * Cancels the connection and ensures that its event handler will not fire
 * again. After this call, any messages that have not yet been sent will be
 * discarded, and the connection will be unwound. If there are messages that are
 * awaiting replies, they will have their reply handlers invoked with the
 * XPC_ERROR_CONNECTION_INVALID error.
 *
 * @param connection
 * The connection object which is to be manipulated.
 *
 * @discussion
 * Cancellation is asynchronous and non-preemptive and therefore this method
 * will not interrupt the execution of an already-running event handler block.
 * If the event handler is executing at the time of this call, it will finish,
 * and then the connection will be canceled, causing a final invocation of the
 * event handler to be scheduled with the XPC_ERROR_CONNECTION_INVALID error.
 * After that invocation, there will be no further invocations of the event
 * handler.
 *
 * The XPC runtime guarantees this non-preemptiveness even for concurrent target
 * queues.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL
void
xpc_connection_cancel(xpc_connection_t connection);

/*!
 * @function xpc_connection_get_name
 * Returns the name of the service with which the connections was created.
 *
 * @param connection
 * The connection object which is to be examined.
 *
 * @result
 * The name of the remote service. If you obtained the connection through an
 * invocation of another connection's event handler, NULL is returned.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT
const char * _Nullable
xpc_connection_get_name(xpc_connection_t connection);

/*!
 * @function xpc_connection_get_euid
 * Returns the EUID of the remote peer.
 *
 * @param connection
 * The connection object which is to be examined.
 *
 * @result
 * The EUID of the remote peer at the time the connection was made.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT
uid_t
xpc_connection_get_euid(xpc_connection_t connection);

/*!
 * @function xpc_connection_get_egid
 * Returns the EGID of the remote peer.
 *
 * @param connection
 * The connection object which is to be examined.
 *
 * @result
 * The EGID of the remote peer at the time the connection was made.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT
gid_t
xpc_connection_get_egid(xpc_connection_t connection);

/*!
 * @function xpc_connection_get_pid
 * Returns the PID of the remote peer.
 *
 * @param connection
 * The connection object which is to be examined.
 *
 * @result
 * The PID of the remote peer.
 *
 * @discussion
 * A given PID is not guaranteed to be unique across an entire boot cycle.
 * Great care should be taken when dealing with this information, as it can go
 * stale after the connection is established. OS X recycles PIDs, and therefore
 * another process could spawn and claim the PID before a message is actually
 * received from the connection.
 *
 * XPC will deliver an error to your event handler if the remote process goes
 * away, but there are no guarantees as to the timing of this notification's
 * delivery either at the kernel layer or at the XPC layer.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT
pid_t
xpc_connection_get_pid(xpc_connection_t connection);

/*!
 * @function xpc_connection_get_asid
 * Returns the audit session identifier of the remote peer.
 *
 * @param connection
 * The connection object which is to be examined.
 *
 * @result
 * The audit session ID of the remote peer at the time the connection was made.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT
au_asid_t
xpc_connection_get_asid(xpc_connection_t connection);

/*!
 * @function xpc_connection_set_context
 * Sets context on an connection.
 *
 * @param connection
 * The connection which is to be manipulated.
 *
 * @param context
 * The context to associate with the connection.
 *
 * @discussion
 * If you must manage the memory of the context object, you must set a finalizer
 * to dispose of it. If this method is called on a connection which already has
 * context associated with it, the finalizer will NOT be invoked. The finalizer
 * is only invoked when the connection is being deallocated.
 *
 * It is recommended that, instead of changing the actual context pointer
 * associated with the object, you instead change the state of the context
 * object itself.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
void
xpc_connection_set_context(xpc_connection_t connection,
	void * _Nullable context);

/*!
 * @function xpc_connection_get_context
 * Returns the context associated with the connection.
 *
 * @param connection
 * The connection which is to be examined.
 *
 * @result
 * The context associated with the connection. NULL if there has been no context
 * associated with the object.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT
void * _Nullable
xpc_connection_get_context(xpc_connection_t connection);

/*!
 * @function xpc_connection_set_finalizer_f
 * Sets the finalizer for the given connection.
 *
 * @param connection
 * The connection on which to set the finalizer.
 *
 * @param finalizer
 * The function that will be invoked when the connection's retain count has
 * dropped to zero and is being torn down.
 *
 * @discussion
 * This method disposes of the context value associated with a connection, as
 * set by {@link xpc_connection_set_context}.
 *
 * For many uses of context objects, this API allows for a convenient shorthand
 * for freeing them. For example, for a context object allocated with malloc(3):
 *
 * xpc_connection_set_finalizer_f(object, free);
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
void
xpc_connection_set_finalizer_f(xpc_connection_t connection,
	xpc_finalizer_t _Nullable finalizer);

__END_DECLS
XPC_ASSUME_NONNULL_END

#endif // __XPC_CONNECTION_H__