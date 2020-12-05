#ifndef __XPC_ENDPOINT_H__
#define __XPC_ENDPOINT_H__

/*!
 * @function xpc_endpoint_create
 * Creates a new endpoint from a connection that is suitable for embedding into
 * messages.
 * 
 * @param connection
 * Only connections obtained through calls to xpc_connection_create*() may be
 * given to this API. Passing any other type of connection is not supported and
 * will result in undefined behavior.
 *
 * @result
 * A new endpoint object. 
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT XPC_NONNULL1
xpc_endpoint_t _Nonnull
xpc_endpoint_create(xpc_connection_t _Nonnull connection);

#endif // __XPC_ENDPOINT_H__ 
