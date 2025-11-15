#ifndef __XPC_RICH_ERROR_H__
#define __XPC_RICH_ERROR_H__

#ifndef __XPC_INDIRECT__
#error "Please #include <xpc/xpc.h> instead of this file directly."
// For HeaderDoc.
#include <xpc/base.h>
#endif // __XPC_INDIRECT__

#ifndef __BLOCKS__
#error "XPC Rich Errors require Blocks support."
#endif // __BLOCKS__

XPC_ASSUME_NONNULL_BEGIN
__BEGIN_DECLS

#pragma mark Properties
/*!
 * @function xpc_rich_error_copy_description
 * Copy the string description of an error.
 *
 * @param error
 * The error to be examined.
 *
 * @result
 * The underlying C string for the provided error. This string should be
 * disposed of with free(3) when done.
 * 
 * This will return NULL if a string description could not be generated.
 */
XPC_EXPORT XPC_WARN_RESULT
char * _Nullable
xpc_rich_error_copy_description(xpc_rich_error_t error);

/*!
 * @function xpc_rich_error_can_retry
 * Whether the operation the error originated from can be retried.
 *
 * @param error
 * The error to be inspected.
 *
 * @result
 * Whether the operation the error originated from can be retried.
 */
XPC_EXPORT XPC_WARN_RESULT
bool
xpc_rich_error_can_retry(xpc_rich_error_t error);

__END_DECLS
XPC_ASSUME_NONNULL_END

#endif // __XPC_RICH_ERROR_H__
