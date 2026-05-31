#ifndef __XPC_PEER_REQ_H__
#define __XPC_PEER_REQ_H__

#ifndef __XPC_INDIRECT__
#error "Please #include <xpc/xpc.h> instead of this file directly."
// For HeaderDoc.
#include <xpc/base.h>
#endif // __XPC_INDIRECT__

XPC_ASSUME_NONNULL_BEGIN
__BEGIN_DECLS

XPC_SWIFT_NOEXPORT
/*!
 * @typedef xpc_peer_requirement_t
 *
 * @abstract
 * XPC peer requirement is an abstract type that represents a validated 
 * requirement on peers.
 *
 * @discussion
 * Users can specify a requirement via `xpc_peer_requirement_create_*` API.
 * These constructors will return a non-null xpc_peer_requirement_t if the 
 * requirement is valid. Users can set a xpc_peer_requirement_t on connections,
 * sessions or listeners using one of `xpc_*_set_peer_requirement` API.
 *
 * xpc_peer_requirement_t is reference counted and concurrency-safe. One
 * xpc_peer_requirement_t can be shared among multiple connections, sessions
 * or listeners.
 */
OS_OBJECT_DECL_CLASS(xpc_peer_requirement);

#pragma mark Constructors

/*!
 * @function xpc_peer_requirement_create_entitlement_exists
 * Create a requirement that the peer has the specified entitlement
 *
 * @param entitlement
 * The entitlement the peer must have. It is safe to deallocate the entitlement
 * string after calling this function.
 *
 * @param error_out
 * An out-parameter that, if set and in the event of an error, will point to an
 * {@link xpc_rich_error_t} describing the details of any errors that occurred.
 *
 * @result
 * On success this returns a new peer requirement object. On failure this will
 * return NULL and if set, error_out will be set to an error describing the
 * failure.
 *
 * @discussion
 * This function will return NULL promptly if the entitlement requirement is
 * invalid.
 */
API_AVAILABLE(macos(26.0), ios(26.0))
API_UNAVAILABLE(tvos, watchos)
XPC_EXPORT XPC_SWIFT_NOEXPORT XPC_RETURNS_RETAINED
xpc_peer_requirement_t _Nullable
xpc_peer_requirement_create_entitlement_exists(const char *entitlement,
		xpc_rich_error_t _Nullable XPC_GIVES_REFERENCE * _Nullable error_out);

/*!
 * @function xpc_peer_requirement_create_entitlement_matches_value
 * Create a requirement that the peer has the entitlement with matching value
 *
 * @param entitlement
 * The entitlement the peer must have. It is safe to deallocate the entitlement
 * string after calling this function.
 *
 * @param value
 * The value that the entitlement must match. It is safe to deallocate the value
 * object after calling this function. Valid xpc types for this object are
 * `XPC_TYPE_BOOL`, `XPC_TYPE_STRING` and `XPC_TYPE_INT64`.
 *
 * @param error_out
 * An out-parameter that, if set and in the event of an error, will point to an
 * {@link xpc_rich_error_t} describing the details of any errors that occurred.
 *
 * @result
 * On success this returns a new peer requirement object. On failure this will
 * return NULL and if set, error_out will be set to an error describing the
 * failure.
 *
 * @discussion
 * This function will return NULL promptly if the entitlement requirement is
 * invalid.
 */
API_AVAILABLE(macos(26.0), ios(26.0))
API_UNAVAILABLE(tvos, watchos)
XPC_EXPORT XPC_SWIFT_NOEXPORT XPC_RETURNS_RETAINED
xpc_peer_requirement_t _Nullable
xpc_peer_requirement_create_entitlement_matches_value(const char *entitlement,
		xpc_object_t value, 
		xpc_rich_error_t _Nullable XPC_GIVES_REFERENCE * _Nullable error_out);

/*!
 * @function xpc_peer_requirement_create_team_identity
 * Create a requirement that the peer has the specified identity and is signed
 * with the same team identifier as the current process
 *
 * @param signing_identifier
 * The optional signing identifier the peer must have. It is safe to deallocate
 * the signing identifier string after calling this function.
 *
 * @param error_out
 * An out-parameter that, if set and in the event of an error, will point to an
 * {@link xpc_rich_error_t} describing the details of any errors that occurred.
 *
 * @result
 * On success this returns a new peer requirement object. On failure this will
 * return NULL and if set, error_out will be set to an error describing the
 * failure.
 *
 * @discussion
 * This function will return NULL promptly if the identity requirement is
 * invalid.
 *
 * The peer process must be signed as either a Testflight app or an App store
 * app, or be signed by an apple issued development certificate, an enterprise
 * distributed certificate (embedded only), or a Developer ID certificate (macOS
 * only)
 */
API_AVAILABLE(macos(26.0), ios(26.0))
API_UNAVAILABLE(tvos, watchos)
XPC_EXPORT XPC_SWIFT_NOEXPORT XPC_RETURNS_RETAINED
xpc_peer_requirement_t _Nullable
xpc_peer_requirement_create_team_identity(
		const char * _Nullable signing_identifier,
		xpc_rich_error_t _Nullable XPC_GIVES_REFERENCE * _Nullable error_out);

/*!
 * @function xpc_peer_requirement_create_platform_identity
 * Create a requirement that the peer has the specified identity and is from
 * platform binary.
 *
 * @param signing_identifier
 * The optional signing identifier the peer must have. If not specified, this
 * function ensures that the peer process' executable is a platform binary. It
 * is safe to deallocate the signing identifier string after calling this
 * function.
 *
 * @param error_out
 * An out-parameter that, if set and in the event of an error, will point to an
 * {@link xpc_rich_error_t} describing the details of any errors that occurred.
 *
 * @result
 * On success this returns a new peer requirement object. On failure this will
 * return NULL and if set, error_out will be set to an error describing the
 * failure.
 *
 * @discussion
 * This function will return NULL promptly if the identity requirement is
 * invalid.
 */
API_AVAILABLE(macos(26.0), ios(26.0))
API_UNAVAILABLE(tvos, watchos)
XPC_EXPORT XPC_SWIFT_NOEXPORT XPC_RETURNS_RETAINED
xpc_peer_requirement_t _Nullable
xpc_peer_requirement_create_platform_identity(
		const char * _Nullable signing_identifier,
		xpc_rich_error_t _Nullable XPC_GIVES_REFERENCE * _Nullable error_out);

/*!
 * @function xpc_peer_requirement_create_lwcr
 * Create a requirement that the peer has the specified lightweight code requirement
 *
 * @param lwcr
 * The lightweight code requirement the peer must have. It is safe to deallocate
 * the lightweight code requirement object after calling this function.
 *
 * @param error_out
 * An out-parameter that, if set and in the event of an error, will point to an
 * {@link xpc_rich_error_t} describing the details of any errors that occurred.
 *
 * @result
 * On success this returns a new peer requirement object. On failure this will
 * return NULL and if set, error_out will be set to an error describing the
 * failure.
 *
 * @discussion
 * This function will return NULL promptly if the lightweight code requirement
 * is invalid.
 *
 * The lightweight code requirement must be an `xpc_dictionary_t` equivalent of
 * an LWCR constraint (see
 * https://developer.apple.com/documentation/security/defining_launch_environment_and_library_constraints
 * for details on the contents of the dictionary)
 *
 * The lightweight code requirement in the example below uses the $or operator
 * to require that an executable’s either signed with the Team ID 8XCUU22SN2, or
 * is an operating system executable: 
 * ```c
 * xpc_object_t or_val = xpc_dictionary_create_empty();
 * xpc_dictionary_set_string(or_val, "team-identifier", "8XCUU22SN2");
 * xpc_dictionary_set_int64(or_val, "validation-category", 1);
 *
 * xpc_object_t lwcr = xpc_dictionary_create_empty();
 * xpc_dictionary_set_value(lwcr, "$or", or_val);
 *
 * xpc_peer_requirement_t req = xpc_peer_requirement_create_lwcr(lwcr, NULL);
 * ```
 */
API_AVAILABLE(macos(26.0), ios(26.0))
API_UNAVAILABLE(tvos, watchos)
XPC_EXPORT XPC_SWIFT_NOEXPORT XPC_RETURNS_RETAINED
xpc_peer_requirement_t _Nullable
xpc_peer_requirement_create_lwcr(xpc_object_t lwcr, 
		xpc_rich_error_t _Nullable XPC_GIVES_REFERENCE * _Nullable error_out);

#pragma mark Matching Peer Requirement on Received Messages

/*!
 * @function xpc_peer_requirement_match_received_message
 * Check the specified requirement against a received message from the peer.
 *
 * @param peer_requirement
 * The requirement the peer must have
 *
 * @param message
 * The received dictionary to be checked
 * 
 * @param error_out
 * An out-parameter that, if set and in the event of an error, will point to an
 * {@link xpc_rich_error_t} describing the details of any errors that occurred.
 *
 * @result
 * On match this returns true. On mismatch or failure this will return false and
 * if set, error_out will be set to an error describing the failure.
 */
API_AVAILABLE(macos(26.0), ios(26.0))
API_UNAVAILABLE(tvos, watchos)
XPC_EXPORT XPC_SWIFT_NOEXPORT
bool
xpc_peer_requirement_match_received_message(xpc_peer_requirement_t peer_requirement,
		xpc_object_t message, 
		xpc_rich_error_t _Nullable XPC_GIVES_REFERENCE * _Nullable error_out);

__END_DECLS
XPC_ASSUME_NONNULL_END

#endif
