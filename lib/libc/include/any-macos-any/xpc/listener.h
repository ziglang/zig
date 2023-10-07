#ifndef __XPC_LISTENER_H__
#define __XPC_LISTENER_H__

#ifndef __XPC_INDIRECT__
#error "Please #include <xpc/xpc.h> instead of this file directly."
// For HeaderDoc.
#include <xpc/base.h>
#endif // __XPC_INDIRECT__

#ifndef __BLOCKS__
#error "XPC Listener require Blocks support."
#endif // __BLOCKS__

XPC_ASSUME_NONNULL_BEGIN
__BEGIN_DECLS

/*!
 * @typedef xpc_listener_t
 *
 * @discussion
 * Listeners represent the server side variant of an XPC Session.
 *
 * Listeners are activated and then begin receiving `xpc_session_t` from peers attempting to
 * connect to the server
 *
 */
OS_OBJECT_DECL_CLASS(xpc_listener);

#pragma mark Constants
/*!
 * @typedef xpc_listener_create_flags_t
 * Constants representing different options available when creating an XPC
 * Listener.
 *
 * @const XPC_LISTENER_CREATE_INACTIVE
 * Indicates that the listener should not be activated during its creation. The
 * returned listener must be manually activated using
 * {@link xpc_listener_activate} before it can be used.
 */
XPC_SWIFT_NOEXPORT
XPC_FLAGS_ENUM(xpc_listener_create_flags, uint64_t,
	XPC_LISTENER_CREATE_NONE XPC_SWIFT_NAME("none") = 0,
	XPC_LISTENER_CREATE_INACTIVE XPC_SWIFT_NAME("inactive") = (1 << 0),
);

#pragma mark Handlers
typedef void (^xpc_listener_incoming_session_handler_t)(xpc_session_t peer);

#pragma mark Helpers
/*!
 * @function xpc_listener_copy_description
 * Copy the string description of the listener.
 *
 * @param listener
 * The listener to be examined.
 *
 * @result
 * The underlying C string description for the provided session. This string
 * should be disposed of with free(3) when done. This will return NULL if a
 * string description could not be generated.
 */
API_AVAILABLE(macos(14.0), ios(17.0), tvos(17.0), watchos(10.0))
XPC_EXPORT XPC_SWIFT_NOEXPORT XPC_WARN_RESULT
char * _Nullable
xpc_listener_copy_description(xpc_listener_t listener);

#pragma mark Server Session Creation
/*!
 * @function xpc_listener_create
 * Creates a listener with the service defined by the provided name
 *
 * @param service
 * The Mach service or XPC Service name to create the listener with.
 *
 * @param target_queue
 * The GCD queue onto which listener events will be submitted. This may be a
 * concurrent queue. This parameter may be NULL, in which case the target queue
 * will be libdispatch's default target queue, defined as
 * DISPATCH_TARGET_QUEUE_DEFAULT.
 *
 * @param flags
 * Additional attributes to create the listener.
 *
 * @param incoming_session_handler
 * The handler block to be called when a peer  is attempting to establish a
 * connection with this listener. The incoming session handler is mandatory.
 *
 * @param error_out
 * An out-parameter that, if set and in the event of an error, will point to an
 * {@link xpc_rich_error_t} describing the details of any errors that occurred.
 *
 * @result
 * On success this returns a new listener object. The returned listener is
 * activated by default and will begin receiving incoming session requests.
 * The caller is responsible for disposing of the returned object with
 * {@link xpc_release} when it is no longer needed. On failure this will return
 * NULL and if set, error_out will be set to an error describing the failure.
 *
 * @discussion
 * This will fail if the specified XPC service is either not found or is
 * unavailable.
 *
 * When the `incoming_session_handler` returns, the peer session will
 * be automatically activated unless the peer session was explicitly cancelled.
 * Before the `incoming_session_handler` returns it must set a message
 * handler on the peer session using `xpc_session_set_incoming_message_handler`
 * or cancel the session using `xpc_session_cancel`. Failure to take one of
 * these two actions will result in an API misuse crash.
 */
API_AVAILABLE(macos(14.0), ios(17.0), tvos(17.0), watchos(10.0))
XPC_EXPORT XPC_SWIFT_NOEXPORT XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_listener_t _Nullable
xpc_listener_create(const char * service,
		dispatch_queue_t _Nullable target_queue,
		xpc_listener_create_flags_t flags,
		xpc_listener_incoming_session_handler_t incoming_session_handler,
		xpc_rich_error_t _Nullable * _Nullable error_out);

#pragma mark Lifecycle
/*!
 * @function xpc_listener_activate
 * Activates a listener.
 *
 * @param listener
 * The listener object to activate.
 *
 * @param error_out
 * An out-parameter that, if set and in the event of an error, will point to an
 * {@link xpc_rich_error_t} describing the details of any errors that occurred.
 *
 * @result
 * Returns whether listener activation succeeded.
 *
 * @discussion
 * xpc_listener_activate must not be called on a listener that has been already
 * activated. Releasing the last reference on an inactive listener that was
 * created with an xpc_listener_create() is undefined.
 */
API_AVAILABLE(macos(14.0), ios(17.0), tvos(17.0), watchos(10.0))
XPC_EXPORT XPC_SWIFT_NOEXPORT
bool
xpc_listener_activate(xpc_listener_t listener,
		xpc_rich_error_t _Nullable * _Nullable error_out);

/*!
 * @function xpc_listener_cancel
 * Cancels a listener.
 *
 * @param listener
 * The listener object to cancel.
 *
 * @discussion
 * Cancellation is asynchronous and non-preemptive.
 *
 * Cancelling a listener will cause peers attempting to connect
 * to the service to hang. In general, a listener does not need
 * to be explicitly cancelled and the process can safely terminate
 * without cancelling the listener.
 */
API_AVAILABLE(macos(14.0), ios(17.0), tvos(17.0), watchos(10.0))
XPC_EXPORT XPC_SWIFT_NOEXPORT
void
xpc_listener_cancel(xpc_listener_t listener);

/*!
 * @function xpc_listener_reject_peer
 * Rejects the incoming peer session
 *
 * @param peer
 * The peer session object to reject. This must be a session that was an argument
 * from an incoming session handler block
 *
 * @param reason
 * The reason that the peer was rejected
 *
 * @discussion
 * The peer session will be cancelled and cannot be used after it has been rejected
 */
API_AVAILABLE(macos(14.0), ios(17.0), tvos(17.0), watchos(10.0))
XPC_EXPORT XPC_SWIFT_NOEXPORT
void
xpc_listener_reject_peer(xpc_session_t peer, const char *reason);

__END_DECLS
XPC_ASSUME_NONNULL_END

#endif // __XPC_LISTENER_H__
