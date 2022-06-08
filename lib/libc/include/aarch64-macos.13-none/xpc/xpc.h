// Copyright (c) 2009-2020 Apple Inc. All rights reserved. 

#ifndef __XPC_H__
#define __XPC_H__

#include <os/object.h>
#include <dispatch/dispatch.h>

#include <sys/mman.h>
#include <uuid/uuid.h>
#include <bsm/audit.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>

#ifndef __XPC_INDIRECT__
#define __XPC_INDIRECT__
#endif // __XPC_INDIRECT__

#include <xpc/base.h>

#if __has_include(<xpc/xpc_transaction_deprecate.h>)
#include <xpc/xpc_transaction_deprecate.h>
#else // __has_include(<xpc/transaction_deprecate.h>)
#define XPC_TRANSACTION_DEPRECATED
#endif // __has_include(<xpc/transaction_deprecate.h>)

XPC_ASSUME_NONNULL_BEGIN
__BEGIN_DECLS

#ifndef __OSX_AVAILABLE_STARTING
#define __OSX_AVAILABLE_STARTING(x, y)
#endif // __OSX_AVAILABLE_STARTING

#define XPC_API_VERSION 20200610

/*!
 * @typedef xpc_type_t
 * A type that describes XPC object types.
 */
typedef const struct _xpc_type_s * xpc_type_t;
#ifndef XPC_TYPE
#define XPC_TYPE(type) const struct _xpc_type_s type
#endif // XPC_TYPE

/*!
 * @typedef xpc_object_t
 * A type that can describe all XPC objects. Dictionaries, arrays, strings, etc.
 * are all described by this type.
 *
 * XPC objects are created with a retain count of 1, and therefore it is the
 * caller's responsibility to call xpc_release() on them when they are no longer
 * needed.
 */

#if OS_OBJECT_USE_OBJC
/* By default, XPC objects are declared as Objective-C types when building with
 * an Objective-C compiler. This allows them to participate in ARC, in RR
 * management by the Blocks runtime and in leaks checking by the static
 * analyzer, and enables them to be added to Cocoa collections.
 *
 * See <os/object.h> for details.
 */
OS_OBJECT_DECL(xpc_object);
#ifndef XPC_DECL
#define XPC_DECL(name) typedef xpc_object_t name##_t
#endif // XPC_DECL

#define XPC_GLOBAL_OBJECT(object) ((OS_OBJECT_BRIDGE xpc_object_t)&(object))
#define XPC_RETURNS_RETAINED OS_OBJECT_RETURNS_RETAINED
XPC_INLINE XPC_NONNULL_ALL
void
_xpc_object_validate(xpc_object_t object) {
	(void)*(unsigned long volatile *)(OS_OBJECT_BRIDGE void *)object;
}
#else // OS_OBJECT_USE_OBJC
typedef void * xpc_object_t;
#define XPC_DECL(name) typedef struct _##name##_s * name##_t
#define XPC_GLOBAL_OBJECT(object) (&(object))
#define XPC_RETURNS_RETAINED
#endif // OS_OBJECT_USE_OBJC 

/*!
 * @typedef xpc_handler_t
 * The type of block that is accepted by the XPC connection APIs.
 *
 * @param object
 * An XPC object that is to be handled. If there was an error, this object will
 * be equal to one of the well-known XPC_ERROR_* dictionaries and can be
 * compared with the equality operator.
 *
 * @discussion
 * You are not responsible for releasing the event object.
 */
#if __BLOCKS__
typedef void (^xpc_handler_t)(xpc_object_t object);
#endif // __BLOCKS__ 

/*!
 * @define XPC_TYPE_CONNECTION
 * A type representing a connection to a named service. This connection is
 * bidirectional and can be used to both send and receive messages. A
 * connection carries the credentials of the remote service provider.
 */
#define XPC_TYPE_CONNECTION (&_xpc_type_connection)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_connection);
XPC_DECL(xpc_connection);

/*!
 * @typedef xpc_connection_handler_t
 * The type of the function that will be invoked for a bundled XPC service when
 * there is a new connection on the service.
 *
 * @param connection
 * A new connection that is equivalent to one received by a listener connection.
 * See the documentation for {@link xpc_connection_set_event_handler} for the
 * semantics associated with the received connection.
 */
typedef void (*xpc_connection_handler_t)(xpc_connection_t connection);

/*!
 * @define XPC_TYPE_ENDPOINT
 * A type representing a connection in serialized form. Unlike a connection, an
 * endpoint is an inert object that does not have any runtime activity
 * associated with it. Thus, it is safe to pass an endpoint in a message. Upon
 * receiving an endpoint, the recipient can use
 * xpc_connection_create_from_endpoint() to create as many distinct connections
 * as desired. 
 */
#define XPC_TYPE_ENDPOINT (&_xpc_type_endpoint)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_endpoint);
XPC_DECL(xpc_endpoint);

/*!
 * @define XPC_TYPE_NULL
 * A type representing a null object. This type is useful for disambiguating
 * an unset key in a dictionary and one which has been reserved but set empty.
 * Also, this type is a way to represent a "null" value in dictionaries, which
 * do not accept NULL.
 */
#define XPC_TYPE_NULL (&_xpc_type_null)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_null);

/*!
 * @define XPC_TYPE_BOOL
 * A type representing a Boolean value.
 */
#define XPC_TYPE_BOOL (&_xpc_type_bool)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_bool);

/*!
 * @define XPC_BOOL_TRUE
 * A constant representing a Boolean value of true. You may compare a Boolean
 * object against this constant to determine its value.
 */
#define XPC_BOOL_TRUE XPC_GLOBAL_OBJECT(_xpc_bool_true)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
const struct _xpc_bool_s _xpc_bool_true;

/*!
 * @define XPC_BOOL_FALSE
 * A constant representing a Boolean value of false. You may compare a Boolean
 * object against this constant to determine its value.
 */
#define XPC_BOOL_FALSE XPC_GLOBAL_OBJECT(_xpc_bool_false)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
const struct _xpc_bool_s _xpc_bool_false;

/*!
 * @define XPC_TYPE_INT64
 * A type representing a signed, 64-bit integer value.
 */
#define XPC_TYPE_INT64 (&_xpc_type_int64)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_int64);

/*!
 * @define XPC_TYPE_UINT64
 * A type representing an unsigned, 64-bit integer value.
 */
#define XPC_TYPE_UINT64 (&_xpc_type_uint64)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_uint64);

/*!
 * @define XPC_TYPE_DOUBLE
 * A type representing an IEEE-compliant, double-precision floating point value.
 */
#define XPC_TYPE_DOUBLE (&_xpc_type_double)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_double);

/*!
 * @define XPC_TYPE_DATE
 * A type representing a date interval. The interval is with respect to the
 * Unix epoch. XPC dates are in Unix time and are thus unaware of local time
 * or leap seconds.
 */
#define XPC_TYPE_DATE (&_xpc_type_date)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_date);

/*!
 * @define XPC_TYPE_DATA
 * A type representing a an arbitrary buffer of bytes.
 */
#define XPC_TYPE_DATA (&_xpc_type_data)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_data);

/*!
 * @define XPC_TYPE_STRING
 * A type representing a NUL-terminated C-string.
 */
#define XPC_TYPE_STRING (&_xpc_type_string)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_string);

/*!
 * @define XPC_TYPE_UUID
 * A type representing a Universally Unique Identifier as defined by uuid(3). 
 */
#define XPC_TYPE_UUID (&_xpc_type_uuid)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_uuid);

/*!
 * @define XPC_TYPE_FD
 * A type representing a POSIX file descriptor.
 */
#define XPC_TYPE_FD (&_xpc_type_fd)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_fd);

/*!
 * @define XPC_TYPE_SHMEM
 * A type representing a region of shared memory.
 */
#define XPC_TYPE_SHMEM (&_xpc_type_shmem)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_shmem);

/*!
 * @define XPC_TYPE_ARRAY
 * A type representing an array of XPC objects. This array must be contiguous,
 * i.e. it cannot contain NULL values. If you wish to indicate that a slot
 * is empty, you can insert a null object. The array will grow as needed to
 * accommodate more objects.
 */
#define XPC_TYPE_ARRAY (&_xpc_type_array)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_array);

/*!
 * @define XPC_TYPE_DICTIONARY
 * A type representing a dictionary of XPC objects, keyed off of C-strings.
 * You may insert NULL values into this collection. The dictionary will grow
 * as needed to accommodate more key/value pairs.
 */
#define XPC_TYPE_DICTIONARY (&_xpc_type_dictionary)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_dictionary);

/*!
 * @define XPC_TYPE_ERROR
 * A type representing an error object. Errors in XPC are dictionaries, but
 * xpc_get_type() will return this type when given an error object. You
 * cannot create an error object directly; XPC will only give them to handlers.
 * These error objects have pointer values that are constant across the lifetime
 * of your process and can be safely compared.
 *
 * These constants are enumerated in the header for the connection object. Error
 * dictionaries may reserve keys so that they can be queried to obtain more
 * detailed information about the error. Currently, the only reserved key is
 * XPC_ERROR_KEY_DESCRIPTION.
 */
#define XPC_TYPE_ERROR (&_xpc_type_error)
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_error);

/*!
 * @define XPC_ERROR_KEY_DESCRIPTION
 * In an error dictionary, querying for this key will return a string object
 * that describes the error in a human-readable way.
 */
#define XPC_ERROR_KEY_DESCRIPTION _xpc_error_key_description
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
const char * const _xpc_error_key_description;

/*!
 * @define XPC_EVENT_KEY_NAME
 * In an event dictionary, this querying for this key will return a string
 * object that describes the event.
 */
#define XPC_EVENT_KEY_NAME _xpc_event_key_name
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
const char * const _xpc_event_key_name;

/*!
 * @define XPC_TYPE_SESSION
 *
 * @discussion
 * Sessions represent a stateful connection between a client and a service. When either end of the connection
 * disconnects, the entire session will be invalidated. In this case the system will make no attempt to
 * reestablish the connection or relaunch the service.
 *
 * Clients can initiate a session with a service that accepts xpc_connection_t connections but session
 * semantics will be maintained.
 *
 */
#define XPC_TYPE_SESSION (&_xpc_type_session)
XPC_EXPORT
XPC_TYPE(_xpc_type_session);
XPC_DECL(xpc_session);

/*!
 * @define XPC_TYPE_RICH_ERROR
 *
 * @discussion
 * Rich errors provide a simple dynamic error type that can indicate whether an
 * error is retry-able or not.
 */
#define XPC_TYPE_RICH_ERROR (&_xpc_type_rich_error)
XPC_EXPORT
XPC_TYPE(_xpc_type_rich_error);
XPC_DECL(xpc_rich_error);

XPC_ASSUME_NONNULL_END
#if !defined(__XPC_BUILDING_XPC__) || !__XPC_BUILDING_XPC__
#include <xpc/endpoint.h>
#include <xpc/debug.h>
#if __BLOCKS__
#include <xpc/activity.h>
#include <xpc/connection.h>
#include <xpc/rich_error.h>
#include <xpc/session.h>
#endif // __BLOCKS__
#undef __XPC_INDIRECT__
#include <launch.h>
#endif // !defined(__XPC_BUILDING_XPC__) || !__XPC_BUILDING_XPC__
XPC_ASSUME_NONNULL_BEGIN

#pragma mark XPC Object Protocol
/*!
 * @function xpc_retain
 *
 * @abstract
 * Increments the reference count of an object.
 *
 * @param object
 * The object which is to be manipulated.
 *
 * @result
 * The object which was given.
 *
 * @discussion
 * Calls to xpc_retain() must be balanced with calls to xpc_release()
 * to avoid leaking memory.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
xpc_object_t
xpc_retain(xpc_object_t object);
#if OS_OBJECT_USE_OBJC_RETAIN_RELEASE
#undef xpc_retain
#define xpc_retain(object) ({ xpc_object_t _o = (object); \
		_xpc_object_validate(_o); [_o retain]; })
#endif // OS_OBJECT_USE_OBJC_RETAIN_RELEASE

/*!
 * @function xpc_release
 *
 * @abstract
 * Decrements the reference count of an object.
 *
 * @param object
 * The object which is to be manipulated.
 *
 * @discussion
 * The caller must take care to balance retains and releases. When creating or
 * retaining XPC objects, the creator obtains a reference on the object. Thus,
 * it is the caller's responsibility to call xpc_release() on those objects when
 * they are no longer needed.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
void
xpc_release(xpc_object_t object);
#if OS_OBJECT_USE_OBJC_RETAIN_RELEASE
#undef xpc_release
#define xpc_release(object) ({ xpc_object_t _o = (object); \
		_xpc_object_validate(_o); [_o release]; })
#endif // OS_OBJECT_USE_OBJC_RETAIN_RELEASE

/*!
 * @function xpc_get_type
 *
 * @abstract
 * Returns the type of an object.
 *
 * @param object
 * The object to examine.
 *
 * @result
 * An opaque pointer describing the type of the object. This pointer is suitable
 * direct comparison to exported type constants with the equality operator.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT
xpc_type_t
xpc_get_type(xpc_object_t object);

/*!
 * @function xpc_type_get_name
 *
 * @abstract
 * Returns a string describing an XPC object type.
 *
 * @param type
 * The type to describe.
 *
 * @result
 * A string describing the type of an object, like "string" or "int64".
 * This string should not be freed or modified.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_15, __IPHONE_13_0)
XPC_EXPORT XPC_NONNULL1
const char *
xpc_type_get_name(xpc_type_t type);

/*!
 * @function xpc_copy
 *
 * @abstract
 * Creates a copy of the object.
 *
 * @param object
 * The object to copy.
 *
 * @result
 * The new object. NULL if the object type does not support copying or if
 * sufficient memory for the copy could not be allocated. Service objects do
 * not support copying.
 *
 * @discussion
 * When called on an array or dictionary, xpc_copy() will perform a deep copy.
 *
 * The object returned is not necessarily guaranteed to be a new object, and
 * whether it is will depend on the implementation of the object being copied.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT XPC_RETURNS_RETAINED
xpc_object_t _Nullable
xpc_copy(xpc_object_t object);

/*!
 * @function xpc_equal
 *
 * @abstract
 * Compares two objects for equality.
 *
 * @param object1
 * The first object to compare.
 *
 * @param object2
 * The second object to compare.
 *
 * @result
 * Returns true if the objects are equal, otherwise false. Two objects must be
 * of the same type in order to be equal.
 *
 * For two arrays to be equal, they must contain the same values at the 
 * same indexes. For two dictionaries to be equal, they must contain the same
 * values for the same keys.
 *
 * Two objects being equal implies that their hashes (as returned by xpc_hash())
 * are also equal.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2 XPC_WARN_RESULT
bool
xpc_equal(xpc_object_t object1, xpc_object_t object2);

/*!
 * @function xpc_hash
 *
 * @abstract
 * Calculates a hash value for the given object.
 *
 * @param object
 * The object for which to calculate a hash value. This value may be modded
 * with a table size for insertion into a dictionary-like data structure.
 *
 * @result
 * The calculated hash value.
 *
 * @discussion
 * Note that the computed hash values for any particular type and value of an 
 * object can change from across releases and platforms and should not be
 * assumed to be constant across all time and space or stored persistently.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_WARN_RESULT
size_t
xpc_hash(xpc_object_t object);

/*!
 * @function xpc_copy_description
 *
 * @abstract
 * Copies a debug string describing the object.
 *
 * @param object
 * The object which is to be examined.
 *
 * @result
 * A string describing object which contains information useful for debugging.
 * This string should be disposed of with free(3) when done.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_WARN_RESULT XPC_NONNULL1
char *
xpc_copy_description(xpc_object_t object);

#pragma mark XPC Object Types
#pragma mark Null
/*!
 * @function xpc_null_create
 *
 * @abstract
 * Creates an XPC object representing the null object.
 *
 * @result
 * A new null object.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_null_create(void);

#pragma mark Boolean
/*!
 * @function xpc_bool_create
 *
 * @abstract
 * Creates an XPC Boolean object.
 *
 * @param value
 * The Boolean primitive value which is to be boxed.
 *
 * @result
 * A new Boolean object. 
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_bool_create(bool value);

/*!
 * @function xpc_bool_get_value
 *
 * @abstract
 * Returns the underlying Boolean value from the object.
 *
 * @param xbool
 * The Boolean object which is to be examined.
 *
 * @result
 * The underlying Boolean value or false if the given object was not an XPC
 * Boolean object.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT
bool
xpc_bool_get_value(xpc_object_t xbool);

#pragma mark Signed Integer
/*!
 * @function xpc_int64_create
 *
 * @abstract
 * Creates an XPC signed integer object.
 *
 * @param value
 * The signed integer value which is to be boxed.
 *
 * @result
 * A new signed integer object.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_int64_create(int64_t value);

/*!
 * @function xpc_int64_get_value
 *
 * @abstract
 * Returns the underlying signed 64-bit integer value from an object.
 *
 * @param xint
 * The signed integer object which is to be examined.
 *
 * @result
 * The underlying signed 64-bit value or 0 if the given object was not an XPC
 * integer object.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
int64_t
xpc_int64_get_value(xpc_object_t xint);

#pragma mark Unsigned Integer
/*!
 * @function xpc_uint64_create
 *
 * @abstract
 * Creates an XPC unsigned integer object.
 *
 * @param value
 * The unsigned integer value which is to be boxed.
 *
 * @result
 * A new unsigned integer object.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_uint64_create(uint64_t value);

/*!
 * @function xpc_uint64_get_value
 *
 * @abstract
 * Returns the underlying unsigned 64-bit integer value from an object.
 *
 * @param xuint
 * The unsigned integer object which is to be examined.
 *
 * @result
 * The underlying unsigned integer value or 0 if the given object was not an XPC
 * unsigned integer object.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
uint64_t
xpc_uint64_get_value(xpc_object_t xuint);

#pragma mark Double
/*!
 * @function xpc_double_create
 *
 * @abstract
 * Creates an XPC double object.
 *
 * @param value
 * The floating point quantity which is to be boxed.
 *
 * @result
 * A new floating point object.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_double_create(double value);

/*!
 * @function xpc_double_get_value
 *
 * @abstract
 * Returns the underlying double-precision floating point value from an object.
 *
 * @param xdouble
 * The floating point object which is to be examined.
 *
 * @result
 * The underlying floating point value or NAN if the given object was not an XPC
 * floating point object.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
double
xpc_double_get_value(xpc_object_t xdouble);

#pragma mark Date
/*!
 * @function xpc_date_create
 *
 * @abstract
 * Creates an XPC date object.
 *
 * @param interval
 * The date interval which is to be boxed. Negative values indicate the number
 * of nanoseconds before the epoch. Positive values indicate the number of
 * nanoseconds after the epoch.
 *
 * @result
 * A new date object.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_date_create(int64_t interval);

/*!
 * @function xpc_date_create_from_current
 *
 * @abstract
 * Creates an XPC date object representing the current date.
 *
 * @result
 * A new date object representing the current date.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_date_create_from_current(void);

/*!
 * @function xpc_date_get_value
 *
 * @abstract
 * Returns the underlying date interval from an object.
 *
 * @param xdate
 * The date object which is to be examined.
 *
 * @result
 * The underlying date interval or 0 if the given object was not an XPC date
 * object.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
int64_t
xpc_date_get_value(xpc_object_t xdate);

#pragma mark Data
/*!
 * @function xpc_data_create
 *
 * @abstract
 * Creates an XPC object representing buffer of bytes.
 *
 * @param bytes
 * The buffer of bytes which is to be boxed. You may create an empty data object
 * by passing NULL for this parameter and 0 for the length. Passing NULL with
 * any other length will result in undefined behavior.
 *
 * @param length
 * The number of bytes which are to be boxed.
 *
 * @result
 * A new data object. 
 *
 * @discussion
 * This method will copy the buffer given into internal storage. After calling
 * this method, it is safe to dispose of the given buffer.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_data_create(const void * _Nullable XPC_SIZEDBY(length) bytes, size_t length);

/*!
 * @function xpc_data_create_with_dispatch_data
 *
 * @abstract
 * Creates an XPC object representing buffer of bytes described by the given GCD
 * data object.
 *
 * @param ddata
 * The GCD data object containing the bytes which are to be boxed. This object
 * is retained by the data object.
 *
 * @result
 * A new data object. 
 *
 * @discussion
 * The object returned by this method will refer to the buffer returned by
 * dispatch_data_create_map(). The point where XPC will make the call to
 * dispatch_data_create_map() is undefined.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT XPC_NONNULL1
xpc_object_t
xpc_data_create_with_dispatch_data(dispatch_data_t ddata);

/*!
 * @function xpc_data_get_length
 *
 * @abstract
 * Returns the length of the data encapsulated by an XPC data object.
 *
 * @param xdata
 * The data object which is to be examined.
 *
 * @result
 * The length of the underlying boxed data or 0 if the given object was not an
 * XPC data object.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
size_t
xpc_data_get_length(xpc_object_t xdata);

/*!
 * @function xpc_data_get_bytes_ptr
 *
 * @abstract
 * Returns a pointer to the internal storage of a data object.
 *
 * @param xdata
 * The data object which is to be examined.
 *
 * @result
 * A pointer to the underlying boxed data or NULL if the given object was not an
 * XPC data object.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
const void * _Nullable
xpc_data_get_bytes_ptr(xpc_object_t xdata);

/*!
 * @function xpc_data_get_bytes
 *
 * @abstract
 * Copies the bytes stored in an data objects into the specified buffer.
 *
 * @param xdata
 * The data object which is to be examined.
 *
 * @param buffer
 * The buffer in which to copy the data object's bytes.
 *
 * @param off
 * The offset at which to begin the copy. If this offset is greater than the 
 * length of the data element, nothing is copied. Pass 0 to start the copy
 * at the beginning of the buffer.
 *
 * @param length
 * The length of the destination buffer.
 *
 * @result
 * The number of bytes that were copied into the buffer or 0 if the given object
 * was not an XPC data object.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1 XPC_NONNULL2
size_t
xpc_data_get_bytes(xpc_object_t xdata, 
	void *buffer, size_t off, size_t length);

#pragma mark String
/*!
 * @function xpc_string_create
 *
 * @abstract
 * Creates an XPC object representing a NUL-terminated C-string.
 *
 * @param string
 * The C-string which is to be boxed.
 *
 * @result
 * A new string object. 
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT XPC_NONNULL1
xpc_object_t
xpc_string_create(const char *string);

/*!
 * @function xpc_string_create_with_format
 *
 * @abstract
 * Creates an XPC object representing a C-string that is generated from the
 * given format string and arguments.
 *
 * @param fmt
 * The printf(3)-style format string from which to construct the final C-string
 * to be boxed.
 *
 * @param ...
 * The arguments which correspond to those specified in the format string.
 *
 * @result
 * A new string object. 
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT XPC_NONNULL1
XPC_PRINTF(1, 2)
xpc_object_t
xpc_string_create_with_format(const char *fmt, ...);

/*!
 * @function xpc_string_create_with_format_and_arguments
 *
 * @abstract
 * Creates an XPC object representing a C-string that is generated from the
 * given format string and argument list pointer.
 *
 * @param fmt
 * The printf(3)-style format string from which to construct the final C-string
 * to be boxed.
 *
 * @param ap
 * A pointer to the arguments which correspond to those specified in the format
 * string.
 *
 * @result
 * A new string object. 
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT XPC_NONNULL1
XPC_PRINTF(1, 0)
xpc_object_t
xpc_string_create_with_format_and_arguments(const char *fmt, va_list ap);

/*!
 * @function xpc_string_get_length
 *
 * @abstract
 * Returns the length of the underlying string.
 *
 * @param xstring
 * The string object which is to be examined.
 *
 * @result
 * The length of the underlying string, not including the NUL-terminator, or 0 
 * if the given object was not an XPC string object.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
size_t
xpc_string_get_length(xpc_object_t xstring);

/*!
 * @function xpc_string_get_string_ptr
 *
 * @abstract
 * Returns a pointer to the internal storage of a string object.
 *
 * @param xstring
 * The string object which is to be examined.
 *
 * @result
 * A pointer to the string object's internal storage or NULL if the given object
 * was not an XPC string object.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
const char * _Nullable
xpc_string_get_string_ptr(xpc_object_t xstring);

#pragma mark UUID
/*!
 * @function xpc_uuid_create
 *
 * @abstract
 * Creates an XPC object representing a universally-unique identifier (UUID) as
 * described by uuid(3).
 *
 * @param uuid
 * The UUID which is to be boxed.
 *
 * @result
 * A new UUID object. 
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT XPC_NONNULL1
xpc_object_t
xpc_uuid_create(const uuid_t XPC_NONNULL_ARRAY uuid);

/*!
 * @function xpc_uuid_get_bytes
 *
 * @abstract
 * Returns a pointer to the the boxed UUID bytes in an XPC UUID object.
 *
 * @param xuuid
 * The UUID object which is to be examined.
 * 
 * @result
 * The underlying <code>uuid_t</code> bytes or NULL if the given object was not
 * an XPC UUID object. The returned pointer may be safely passed to the uuid(3)
 * APIs.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
const uint8_t * _Nullable
xpc_uuid_get_bytes(xpc_object_t xuuid);

#pragma mark File Descriptors
/*!
 * @function xpc_fd_create
 *
 * @abstract
 * Creates an XPC object representing a POSIX file descriptor.
 *
 * @param fd
 * The file descriptor which is to be boxed.
 *
 * @result
 * A new file descriptor object. NULL if sufficient memory could not be
 * allocated or if the given file descriptor was not valid.
 *
 * @discussion
 * This method performs the equivalent of a dup(2) on the descriptor, and thus
 * it is safe to call close(2) on the descriptor after boxing it with a file
 * descriptor object.
 *
 * IMPORTANT: Pointer equality is the ONLY valid test for equality between two
 * file descriptor objects. There is no reliable way to determine whether two
 * file descriptors refer to the same inode with the same capabilities, so two
 * file descriptor objects created from the same underlying file descriptor
 * number will not compare equally with xpc_equal(). This is also true of a
 * file descriptor object created using xpc_copy() and the original.
 *
 * This also implies that two collections containing file descriptor objects
 * cannot be equal unless the exact same object was inserted into both.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t _Nullable
xpc_fd_create(int fd);

/*!
 * @function xpc_fd_dup
 *
 * @abstract
 * Returns a file descriptor that is equivalent to the one boxed by the file
 * file descriptor object.
 *
 * @param xfd
 * The file descriptor object which is to be examined.
 *
 * @result
 * A file descriptor that is equivalent to the one originally given to
 * xpc_fd_create(). If the descriptor could not be created or if the given 
 * object was not an XPC file descriptor, -1 is returned.
 *
 * @discussion
 * Multiple invocations of xpc_fd_dup() will not return the same file descriptor
 * number, but they will return descriptors that are equivalent, as though they
 * had been created by dup(2).
 *
 * The caller is responsible for calling close(2) on the returned descriptor.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
int
xpc_fd_dup(xpc_object_t xfd);

#pragma mark Shared Memory
/*!
 * @function xpc_shmem_create
 *
 * @abstract
 * Creates an XPC object representing the given shared memory region.
 *
 * @param region
 * A pointer to a region of shared memory, created through a call to mmap(2)
 * with the MAP_SHARED flag, which is to be boxed.
 *
 * @param length
 * The length of the region.
 *
 * @result
 * A new shared memory object.
 *
 * @discussion
 * Only memory regions whose exact characteristics are known to the caller
 * should be boxed using this API. Memory returned from malloc(3) may not be
 * safely shared on either OS X or iOS because the underlying virtual memory
 * objects for malloc(3)ed allocations are owned by the malloc(3) subsystem and
 * not the caller of malloc(3).
 *
 * If you wish to share a memory region that you receive from another subsystem,
 * part of the interface contract with that other subsystem must include how to
 * create the region of memory, or sharing it may be unsafe.
 *
 * Certain operations may internally fragment a region of memory in a way that
 * would truncate the range detected by the shared memory object. vm_copy(), for
 * example, may split the region into multiple parts to avoid copying certain
 * page ranges. For this reason, it is recommended that you delay all VM
 * operations until the shared memory object has been created so that the VM
 * system knows that the entire range is intended for sharing.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT XPC_NONNULL1
xpc_object_t
xpc_shmem_create(void *region, size_t length);

/*!
 * @function xpc_shmem_map
 *
 * @abstract
 * Maps the region boxed by the XPC shared memory object into the caller's
 * address space.
 *
 * @param xshmem
 * The shared memory object to be examined.
 *
 * @param region
 * On return, this will point to the region at which the shared memory was
 * mapped.
 *
 * @result
 * The length of the region that was mapped. If the mapping failed or if the
 * given object was not an XPC shared memory object, 0 is returned. The length 
 * of the mapped region will always be an integral page size, even if the
 * creator of the region specified a non-integral page size.
 *
 * @discussion
 * The resulting region must be disposed of with munmap(2).
 *
 * It is the responsibility of the caller to manage protections on the new
 * region accordingly. 
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
size_t
xpc_shmem_map(xpc_object_t xshmem, void * _Nullable * _Nonnull region);

#pragma mark Array
/*!
 * @typedef xpc_array_applier_t
 * A block to be invoked for every value in the array.
 *
 * @param index
 * The current index in the iteration.
 *
 * @param value
 * The current value in the iteration.
 *
 * @result
 * A Boolean indicating whether iteration should continue.
 */
#ifdef __BLOCKS__
typedef bool (^xpc_array_applier_t)(size_t index, xpc_object_t _Nonnull value);
#endif // __BLOCKS__ 

/*!
 * @function xpc_array_create
 *
 * @abstract
 * Creates an XPC object representing an array of XPC objects.
 *
 * @discussion
 * This array must be contiguous and cannot contain any NULL values. If you
 * wish to insert the equivalent of a NULL value, you may use the result of
 * {@link xpc_null_create}.
 *
 * @param objects
 * An array of XPC objects which is to be boxed. The order of this array is
 * preserved in the object. If this array contains a NULL value, the behavior
 * is undefined. This parameter may be NULL only if the count is 0.
 *
 * @param count
 * The number of objects in the given array. If the number passed is less than
 * the actual number of values in the array, only the specified number of items
 * are inserted into the resulting array. If the number passed is more than
 * the the actual number of values, the behavior is undefined.
 *
 * @result
 * A new array object. 
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_array_create(
	const xpc_object_t _Nonnull *XPC_COUNTEDBY(count) _Nullable objects,
	size_t count);

/*!
 * @function xpc_array_create_empty
 *
 * @abstract
 * Creates an XPC object representing an array of XPC objects.
 *
 * @result
 * A new array object.
 *
 * @see
 * xpc_array_create
 */
API_AVAILABLE(macos(11.0), ios(14.0), tvos(14.0), watchos(7.0))
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_array_create_empty(void);

/*!
 * @function xpc_array_set_value
 *
 * @abstract
 * Inserts the specified object into the array at the specified index.
 *
 * @param xarray
 * The array object which is to be manipulated.
 *
 * @param index
 * The index at which to insert the value. This value must lie within the index
 * space of the array (0 to N-1 inclusive, where N is the count of the array).
 * If the index is outside that range, the behavior is undefined.
 * 
 * @param value
 * The object to insert. This value is retained by the array and cannot be
 * NULL. If there is already a value at the specified index, it is released,
 * and the new value is inserted in its place.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL3
void
xpc_array_set_value(xpc_object_t xarray, size_t index, xpc_object_t value);

/*!
 * @function xpc_array_append_value
 *
 * @abstract
 * Appends an object to an XPC array.
 *
 * @param xarray
 * The array object which is to be manipulated.
 *
 * @param value
 * The object to append. This object is retained by the array.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2
void
xpc_array_append_value(xpc_object_t xarray, xpc_object_t value);

/*!
 * @function xpc_array_get_count
 *
 * @abstract
 * Returns the count of values currently in the array.
 *
 * @param xarray
 * The array object which is to be examined.
 *
 * @result
 * The count of values in the array or 0 if the given object was not an XPC 
 * array.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
size_t
xpc_array_get_count(xpc_object_t xarray);

/*!
 * @function xpc_array_get_value
 *
 * @abstract
 * Returns the value at the specified index in the array.
 *
 * @param xarray
 * The array object which is to be examined.
 *
 * @param index
 * The index of the value to obtain. This value must lie within the range of
 * indexes as specified in xpc_array_set_value().
 * 
 * @result
 * The object at the specified index within the array or NULL if the given
 * object was not an XPC array.
 *
 * @discussion
 * This method does not grant the caller a reference to the underlying object,
 * and thus the caller is not responsible for releasing the object.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL
xpc_object_t
xpc_array_get_value(xpc_object_t xarray, size_t index);

/*!
 * @function xpc_array_apply
 *
 * @abstract
 * Invokes the given block for every value in the array.
 *
 * @param xarray
 * The array object which is to be examined.
 *
 * @param applier
 * The block which this function applies to every element in the array.
 * 
 * @result
 * A Boolean indicating whether iteration of the array completed successfully.
 * Iteration will only fail if the applier block returns false.
 *
 * @discussion
 * You should not modify an array's contents during iteration. The array indexes
 * are iterated in order.
 */
#ifdef __BLOCKS__
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL
bool
xpc_array_apply(xpc_object_t xarray, XPC_NOESCAPE xpc_array_applier_t applier);
#endif // __BLOCKS__ 

#pragma mark Array Primitive Setters
/*!
 * @define XPC_ARRAY_APPEND
 * A constant that may be passed as the destination index to the class of
 * primitive XPC array setters indicating that the given primitive should be
 * appended to the array.
 */
#define XPC_ARRAY_APPEND ((size_t)(-1))

/*!
 * @function xpc_array_set_bool
 *
 * @abstract
 * Inserts a <code>bool</code> (primitive) value into an array.
 *
 * @param xarray
 * The array object which is to be manipulated.
 *
 * @param index
 * The index at which to insert the value. This value must lie within the index
 * space of the array (0 to N-1 inclusive, where N is the count of the array) or
 * be XPC_ARRAY_APPEND. If the index is outside that range, the behavior is
 * undefined.
 *
 * @param value
 * The <code>bool</code> value to insert. After calling this method, the XPC
 * object corresponding to the primitive value inserted may be safely retrieved
 * with {@link xpc_array_get_value()}.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
void
xpc_array_set_bool(xpc_object_t xarray, size_t index, bool value);

/*!
 * @function xpc_array_set_int64
 *
 * @abstract
 * Inserts an <code>int64_t</code> (primitive) value into an array.
 *
 * @param xarray
 * The array object which is to be manipulated.
 *
 * @param index
 * The index at which to insert the value. This value must lie within the index
 * space of the array (0 to N-1 inclusive, where N is the count of the array) or
 * be XPC_ARRAY_APPEND. If the index is outside that range, the behavior is
 * undefined.
 *
 * @param value
 * The <code>int64_t</code> value to insert. After calling this method, the XPC
 * object corresponding to the primitive value inserted may be safely retrieved
 * with {@link xpc_array_get_value()}.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
void
xpc_array_set_int64(xpc_object_t xarray, size_t index, int64_t value);

/*!
 * @function xpc_array_set_uint64
 *
 * @abstract
 * Inserts a <code>uint64_t</code> (primitive) value into an array.
 *
 * @param xarray
 * The array object which is to be manipulated.
 *
 * @param index
 * The index at which to insert the value. This value must lie within the index
 * space of the array (0 to N-1 inclusive, where N is the count of the array) or
 * be XPC_ARRAY_APPEND. If the index is outside that range, the behavior is
 * undefined.
 *
 * @param value
 * The <code>uint64_t</code> value to insert. After calling this method, the XPC
 * object corresponding to the primitive value inserted may be safely retrieved
 * with {@link xpc_array_get_value()}.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
void
xpc_array_set_uint64(xpc_object_t xarray, size_t index, uint64_t value);

/*!
 * @function xpc_array_set_double
 *
 * @abstract
 * Inserts a <code>double</code> (primitive) value into an array.
 *
 * @param xarray
 * The array object which is to be manipulated.
 *
 * @param index
 * The index at which to insert the value. This value must lie within the index
 * space of the array (0 to N-1 inclusive, where N is the count of the array) or
 * be XPC_ARRAY_APPEND. If the index is outside that range, the behavior is
 * undefined.
 *
 * @param value
 * The <code>double</code> value to insert. After calling this method, the XPC
 * object corresponding to the primitive value inserted may be safely retrieved
 * with {@link xpc_array_get_value()}.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
void
xpc_array_set_double(xpc_object_t xarray, size_t index, double value);

/*!
 * @function xpc_array_set_date
 *
 * @abstract
 * Inserts a date value into an array.
 *
 * @param xarray
 * The array object which is to be manipulated.
 *
 * @param index
 * The index at which to insert the value. This value must lie within the index
 * space of the array (0 to N-1 inclusive, where N is the count of the array) or
 * be XPC_ARRAY_APPEND. If the index is outside that range, the behavior is
 * undefined.
 *
 * @param value
 * The date value to insert, represented as an <code>int64_t</code>. After 
 * calling this method, the XPC object corresponding to the primitive value 
 * inserted may be safely retrieved with {@link xpc_array_get_value()}.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
void
xpc_array_set_date(xpc_object_t xarray, size_t index, int64_t value);

/*!
 * @function xpc_array_set_data
 *
 * @abstract
 * Inserts a raw data value into an array.
 *
 * @param xarray
 * The array object which is to be manipulated.
 *
 * @param index
 * The index at which to insert the value. This value must lie within the index
 * space of the array (0 to N-1 inclusive, where N is the count of the array) or
 * be XPC_ARRAY_APPEND. If the index is outside that range, the behavior is
 * undefined.
 *
 * @param bytes
 * The raw data to insert. After calling this method, the XPC object
 * corresponding to the primitive value inserted may be safely retrieved with
 * {@link xpc_array_get_value()}.
 *
 * @param length
 * The length of the data.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL3
void
xpc_array_set_data(xpc_object_t xarray, size_t index,
	const void *XPC_SIZEDBY(length) bytes, size_t length);

/*!
 * @function xpc_array_set_string
 *
 * @abstract
 * Inserts a C string into an array.
 *
 * @param xarray
 * The array object which is to be manipulated.
 *
 * @param index
 * The index at which to insert the value. This value must lie within the index
 * space of the array (0 to N-1 inclusive, where N is the count of the array) or
 * be XPC_ARRAY_APPEND. If the index is outside that range, the behavior is
 * undefined.
 *
 * @param string
 * The C string to insert. After calling this method, the XPC object
 * corresponding to the primitive value inserted may be safely retrieved with
 * {@link xpc_array_get_value()}.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL3
void
xpc_array_set_string(xpc_object_t xarray, size_t index, const char *string);

/*!
 * @function xpc_array_set_uuid
 *
 * @abstract
 * Inserts a <code>uuid_t</code> (primitive) value into an array.
 *
 * @param xarray
 * The array object which is to be manipulated.
 *
 * @param index
 * The index at which to insert the value. This value must lie within the index
 * space of the array (0 to N-1 inclusive, where N is the count of the array) or
 * be XPC_ARRAY_APPEND. If the index is outside that range, the behavior is
 * undefined.
 *
 * @param uuid
 * The UUID primitive to insert. After calling this method, the XPC object
 * corresponding to the primitive value inserted may be safely retrieved with
 * {@link xpc_array_get_value()}.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL3
void
xpc_array_set_uuid(xpc_object_t xarray, size_t index,
	const uuid_t XPC_NONNULL_ARRAY uuid);

/*!
 * @function xpc_array_set_fd
 *
 * @abstract
 * Inserts a file descriptor into an array.
 *
 * @param xarray
 * The array object which is to be manipulated.
 *
 * @param index
 * The index at which to insert the value. This value must lie within the index
 * space of the array (0 to N-1 inclusive, where N is the count of the array) or
 * be XPC_ARRAY_APPEND. If the index is outside that range, the behavior is
 * undefined.
 *
 * @param fd
 * The file descriptor to insert. After calling this method, the XPC object
 * corresponding to the primitive value inserted may be safely retrieved with
 * {@link xpc_array_get_value()}.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1
void
xpc_array_set_fd(xpc_object_t xarray, size_t index, int fd);

/*!
 * @function xpc_array_set_connection
 *
 * @abstract
 * Inserts a connection into an array.
 *
 * @param xarray
 * The array object which is to be manipulated.
 *
 * @param index
 * The index at which to insert the value. This value must lie within the index
 * space of the array (0 to N-1 inclusive, where N is the count of the array) or
 * be XPC_ARRAY_APPEND. If the index is outside that range, the behavior is
 * undefined.
 *
 * @param connection
 * The connection to insert. After calling this method, the XPC object
 * corresponding to the primitive value inserted may be safely retrieved with
 * {@link xpc_array_get_value()}. The connection is NOT retained by the array.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL3
void
xpc_array_set_connection(xpc_object_t xarray, size_t index,
	xpc_connection_t connection);

#pragma mark Array Primitive Getters
/*!
 * @function xpc_array_get_bool
 *
 * @abstract
 * Gets a <code>bool</code> primitive value from an array directly.
 *
 * @param xarray
 * The array which is to be examined.
 *
 * @param index
 * The index of the value to obtain. This value must lie within the index space
 * of the array (0 to N-1 inclusive, where N is the count of the array). If the
 * index is outside that range, the behavior is undefined.
 *
 * @result
 * The underlying <code>bool</code> value at the specified index. false if the
 * value at the specified index is not a Boolean value.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
bool
xpc_array_get_bool(xpc_object_t xarray, size_t index);

/*!
 * @function xpc_array_get_int64
 *
 * @abstract
 * Gets an <code>int64_t</code> primitive value from an array directly.
 *
 * @param xarray
 * The array which is to be examined.
 *
 * @param index
 * The index of the value to obtain. This value must lie within the index space
 * of the array (0 to N-1 inclusive, where N is the count of the array). If the
 * index is outside that range, the behavior is undefined.
 *
 * @result
 * The underlying <code>int64_t</code> value at the specified index. 0 if the
 * value at the specified index is not a signed integer value. 
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
int64_t
xpc_array_get_int64(xpc_object_t xarray, size_t index);

/*!
 * @function xpc_array_get_uint64
 *
 * @abstract
 * Gets a <code>uint64_t</code> primitive value from an array directly.
 *
 * @param xarray
 * The array which is to be examined.
 *
 * @param index
 * The index of the value to obtain. This value must lie within the index space
 * of the array (0 to N-1 inclusive, where N is the count of the array). If the
 * index is outside that range, the behavior is undefined.
 *
 * @result
 * The underlying <code>uint64_t</code> value at the specified index. 0 if the
 * value at the specified index is not an unsigned integer value.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
uint64_t
xpc_array_get_uint64(xpc_object_t xarray, size_t index);

/*!
 * @function xpc_array_get_double
 *
 * @abstract
 * Gets a <code>double</code> primitive value from an array directly.
 *
 * @param xarray
 * The array which is to be examined.
 *
 * @param index
 * The index of the value to obtain. This value must lie within the index space
 * of the array (0 to N-1 inclusive, where N is the count of the array). If the
 * index is outside that range, the behavior is undefined.
 *
 * @result
 * The underlying <code>double</code> value at the specified index. NAN if the
 * value at the specified index is not a floating point value.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
double
xpc_array_get_double(xpc_object_t xarray, size_t index);

/*!
 * @function xpc_array_get_date
 *
 * @abstract
 * Gets a date interval from an array directly.
 *
 * @param xarray
 * The array which is to be examined.
 *
 * @param index
 * The index of the value to obtain. This value must lie within the index space
 * of the array (0 to N-1 inclusive, where N is the count of the array). If the
 * index is outside that range, the behavior is undefined.
 *
 * @result
 * The underlying date interval at the specified index. 0 if the value at the
 * specified index is not a date value.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
int64_t
xpc_array_get_date(xpc_object_t xarray, size_t index);

/*!
 * @function xpc_array_get_data
 *
 * @abstract
 * Gets a pointer to the raw bytes of a data object from an array directly.
 *
 * @param xarray
 * The array which is to be examined.
 *
 * @param index
 * The index of the value to obtain. This value must lie within the index space
 * of the array (0 to N-1 inclusive, where N is the count of the array). If the
 * index is outside that range, the behavior is undefined.
 *
 * @param length
 * Upon return output, will contain the length of the data corresponding to the
 * specified key.
 *
 * @result
 * The underlying bytes at the specified index. NULL if the value at the
 * specified index is not a data value.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
const void * _Nullable
xpc_array_get_data(xpc_object_t xarray, size_t index,
	size_t * _Nullable length);

/*!
 * @function xpc_array_get_string
 *
 * @abstract
 * Gets a C string value from an array directly.
 *
 * @param xarray
 * The array which is to be examined.
 *
 * @param index
 * The index of the value to obtain. This value must lie within the index space
 * of the array (0 to N-1 inclusive, where N is the count of the array). If the
 * index is outside that range, the behavior is undefined.
 *
 * @result
 * The underlying C string at the specified index. NULL if the value at the
 * specified index is not a C string value.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
const char * _Nullable
xpc_array_get_string(xpc_object_t xarray, size_t index);

/*!
 * @function xpc_array_get_uuid
 *
 * @abstract
 * Gets a <code>uuid_t</code> value from an array directly.
 *
 * @param xarray
 * The array which is to be examined.
 *
 * @param index
 * The index of the value to obtain. This value must lie within the index space
 * of the array (0 to N-1 inclusive, where N is the count of the array). If the
 * index is outside that range, the behavior is undefined.
 *
 * @result
 * The underlying <code>uuid_t</code> value at the specified index. The null
 * UUID if the value at the specified index is not a UUID value. The returned
 * pointer may be safely passed to the uuid(3) APIs.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
const uint8_t * _Nullable
xpc_array_get_uuid(xpc_object_t xarray, size_t index);

/*!
 * @function xpc_array_dup_fd
 *
 * @abstract
 * Gets a file descriptor from an array directly.
 *
 * @param xarray
 * The array which is to be examined.
 *
 * @param index
 * The index of the value to obtain. This value must lie within the index space
 * of the array (0 to N-1 inclusive, where N is the count of the array). If the
 * index is outside that range, the behavior is undefined.
 *
 * @result
 * A new file descriptor created from the value at the specified index. You are
 * responsible for close(2)ing this descriptor. -1 if the value at the specified
 * index is not a file descriptor value.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
int
xpc_array_dup_fd(xpc_object_t xarray, size_t index);

/*!
 * @function xpc_array_create_connection
 *
 * @abstract
 * Creates a connection object from an array directly.
 *
 * @param xarray
 * The array which is to be examined.
 *
 * @param index
 * The index of the value to obtain. This value must lie within the index space
 * of the array (0 to N-1 inclusive, where N is the count of the array). If the
 * index is outside that range, the behavior is undefined.
 *
 * @result
 * A new connection created from the value at the specified index. You are
 * responsible for calling xpc_release() on the returned connection. NULL if the
 * value at the specified index is not an endpoint containing a connection. Each
 * call to this method for the same index in the same array will yield a
 * different connection. See {@link xpc_connection_create_from_endpoint()} for
 * discussion as to the responsibilities when dealing with the returned
 * connection.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT XPC_NONNULL1
xpc_connection_t _Nullable
xpc_array_create_connection(xpc_object_t xarray, size_t index);

/*!
 * @function xpc_array_get_dictionary
 *
 * @abstract
 * Returns the dictionary at the specified index in the array.
 *
 * @param xarray
 * The array object which is to be examined.
 *
 * @param index
 * The index of the value to obtain. This value must lie within the range of
 * indexes as specified in xpc_array_set_value().
 * 
 * @result
 * The object at the specified index within the array or NULL if the given
 * object was not an XPC array or if the the value at the specified index was
 * not a dictionary.
 *
 * @discussion
 * This method does not grant the caller a reference to the underlying object,
 * and thus the caller is not responsible for releasing the object.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_11, __IPHONE_9_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
xpc_object_t _Nullable
xpc_array_get_dictionary(xpc_object_t xarray, size_t index);

/*!
 * @function xpc_array_get_array
 *
 * @abstract
 * Returns the array at the specified index in the array.
 *
 * @param xarray
 * The array object which is to be examined.
 *
 * @param index
 * The index of the value to obtain. This value must lie within the range of
 * indexes as specified in xpc_array_set_value().
 * 
 * @result
 * The object at the specified index within the array or NULL if the given
 * object was not an XPC array or if the the value at the specified index was
 * not an array.
 *
 * @discussion
 * This method does not grant the caller a reference to the underlying object,
 * and thus the caller is not responsible for releasing the object.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_11, __IPHONE_9_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
xpc_object_t _Nullable
xpc_array_get_array(xpc_object_t xarray, size_t index);

#pragma mark Dictionary
/*!
 * @typedef xpc_dictionary_applier_t
 * A block to be invoked for every key/value pair in the dictionary.
 *
 * @param key
 * The current key in the iteration.
 *
 * @param value
 * The current value in the iteration.
 *
 * @result
 * A Boolean indicating whether iteration should continue.
 */
#ifdef __BLOCKS__
typedef bool (^xpc_dictionary_applier_t)(const char * _Nonnull key,
		xpc_object_t _Nonnull value);
#endif // __BLOCKS__ 

/*!
 * @function xpc_dictionary_create
 *
 * @abstract
 * Creates an XPC object representing a dictionary of XPC objects keyed to
 * C-strings.
 *
 * @param keys
 * An array of C-strings that are to be the keys for the values to be inserted.
 * Each element of this array is copied into the dictionary's internal storage.
 * Elements of this array may NOT be NULL.
 *
 * @param values
 * A C-array that is parallel to the array of keys, consisting of objects that
 * are to be inserted. Each element in this array is retained. Elements in this
 * array may be NULL.
 *
 * @param count
 * The number of key/value pairs in the given arrays. If the count is less than
 * the actual count of values, only that many key/value pairs will be inserted
 * into the dictionary.
 *
 * If the count is more than the the actual count of key/value pairs, the
 * behavior is undefined. If one array is NULL and the other is not, the 
 * behavior is undefined. If both arrays are NULL and the count is non-0, the
 * behavior is undefined.
 *
 * @result
 * The new dictionary object.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_dictionary_create(
	const char *XPC_CSTRING _Nonnull const *XPC_COUNTEDBY(count) _Nullable keys,
	const xpc_object_t _Nullable *XPC_COUNTEDBY(count) _Nullable values, size_t count);

/*!
 * @function xpc_dictionary_create_empty
 *
 * @abstract
 * Creates an XPC object representing a dictionary of XPC objects keyed to
 * C-strings.
 *
 * @result
 * The new dictionary object.
 *
 * @see
 * xpc_dictionary_create
 */
API_AVAILABLE(macos(11.0), ios(14.0), tvos(14.0), watchos(7.0))
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_dictionary_create_empty(void);

/*!
 * @function xpc_dictionary_create_reply
 * 
 * @abstract
 * Creates a dictionary that is in reply to the given dictionary.
 *
 * @param original
 * The original dictionary that is to be replied to.
 *
 * @result
 * The new dictionary object. NULL if the object was not a dictionary with a
 * reply context.
 *
 * @discussion
 * After completing successfully on a dictionary, this method may not be called
 * again on that same dictionary. Attempts to do so will return NULL.
 *
 * When this dictionary is sent across the reply connection, the remote end's
 * reply handler is invoked.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT XPC_NONNULL_ALL
xpc_object_t _Nullable
xpc_dictionary_create_reply(xpc_object_t original);

/*!
 * @function xpc_dictionary_set_value
 *
 * @abstract
 * Sets the value for the specified key to the specified object.
 *
 * @param xdict
 * The dictionary object which is to be manipulated.
 *
 * @param key
 * The key for which the value shall be set.
 *
 * @param value
 * The object to insert. The object is retained by the dictionary. If there
 * already exists a value for the specified key, the old value is released
 * and overwritten by the new value. This parameter may be NULL, in which case
 * the value corresponding to the specified key is deleted if present.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2
void
xpc_dictionary_set_value(xpc_object_t xdict, const char *key,
	xpc_object_t _Nullable value);

/*!
 * @function xpc_dictionary_get_value
 *
 * @abstract
 * Returns the value for the specified key.
 *
 * @param xdict
 * The dictionary object which is to be examined.
 *
 * @param key
 * The key whose value is to be obtained.
 * 
 * @result
 * The object for the specified key within the dictionary. NULL if there is no
 * value associated with the specified key or if the given object was not an
 * XPC dictionary.
 *
 * @discussion
 * This method does not grant the caller a reference to the underlying object,
 * and thus the caller is not responsible for releasing the object.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1 XPC_NONNULL2
xpc_object_t _Nullable
xpc_dictionary_get_value(xpc_object_t xdict, const char *key);

/*!
 * @function xpc_dictionary_get_count
 *
 * @abstract
 * Returns the number of values stored in the dictionary.
 *
 * @param xdict
 * The dictionary object which is to be examined.
 *
 * @result
 * The number of values stored in the dictionary or 0 if the given object was 
 * not an XPC dictionary. Calling xpc_dictionary_set_value() with a non-NULL
 * value will increment the count. Calling xpc_dictionary_set_value() with a 
 * NULL value will decrement the count.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
size_t
xpc_dictionary_get_count(xpc_object_t xdict);

/*!
 * @function xpc_dictionary_apply
 *
 * @abstract
 * Invokes the given block for every key/value pair in the dictionary.
 *
 * @param xdict
 * The dictionary object which is to be examined.
 *
 * @param applier
 * The block which this function applies to every key/value pair in the 
 * dictionary.
 * 
 * @result
 * A Boolean indicating whether iteration of the dictionary completed
 * successfully. Iteration will only fail if the applier block returns false.
 *
 * @discussion
 * You should not modify a dictionary's contents during iteration. There is no
 * guaranteed order of iteration over dictionaries.
 */
#ifdef __BLOCKS__
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL_ALL
bool
xpc_dictionary_apply(xpc_object_t xdict,
		XPC_NOESCAPE xpc_dictionary_applier_t applier);
#endif // __BLOCKS__ 

/*!
 * @function xpc_dictionary_get_remote_connection
 *
 * @abstract
 * Returns the connection from which the dictionary was received.
 *
 * @param xdict
 * The dictionary object which is to be examined.
 *
 * @result
 * If the dictionary was received by a connection event handler or a dictionary
 * created through xpc_dictionary_create_reply(), a connection object over which
 * a reply message can be sent is returned. For any other dictionary, NULL is
 * returned.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
xpc_connection_t _Nullable
xpc_dictionary_get_remote_connection(xpc_object_t xdict);

#pragma mark Dictionary Primitive Setters
/*!
 * @function xpc_dictionary_set_bool
 *
 * @abstract
 * Inserts a <code>bool</code> (primitive) value into a dictionary.
 *
 * @param xdict
 * The dictionary which is to be manipulated.
 *
 * @param key
 * The key for which the primitive value shall be set.
 *
 * @param value
 * The <code>bool</code> value to insert. After calling this method, the XPC
 * object corresponding to the primitive value inserted may be safely retrieved
 * with {@link xpc_dictionary_get_value()}.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2
void
xpc_dictionary_set_bool(xpc_object_t xdict, const char *key, bool value);

/*!
 * @function xpc_dictionary_set_int64
 *
 * @abstract
 * Inserts an <code>int64_t</code> (primitive) value into a dictionary.
 *
 * @param xdict
 * The dictionary which is to be manipulated.
 *
 * @param key
 * The key for which the primitive value shall be set.
 *
 * @param value
 * The <code>int64_t</code> value to insert. After calling this method, the XPC
 * object corresponding to the primitive value inserted may be safely retrieved
 * with {@link xpc_dictionary_get_value()}.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2
void
xpc_dictionary_set_int64(xpc_object_t xdict, const char *key, int64_t value);

/*!
 * @function xpc_dictionary_set_uint64
 *
 * @abstract
 * Inserts a <code>uint64_t</code> (primitive) value into a dictionary.
 *
 * @param xdict
 * The dictionary which is to be manipulated.
 *
 * @param key
 * The key for which the primitive value shall be set.
 *
 * @param value
 * The <code>uint64_t</code> value to insert. After calling this method, the XPC
 * object corresponding to the primitive value inserted may be safely retrieved
 * with {@link xpc_dictionary_get_value()}.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2
void
xpc_dictionary_set_uint64(xpc_object_t xdict, const char *key, uint64_t value);

/*!
 * @function xpc_dictionary_set_double
 *
 * @abstract
 * Inserts a <code>double</code> (primitive) value into a dictionary.
 *
 * @param xdict
 * The dictionary which is to be manipulated.
 *
 * @param key
 * The key for which the primitive value shall be set.
 *
 * @param value
 * The <code>double</code> value to insert. After calling this method, the XPC
 * object corresponding to the primitive value inserted may be safely retrieved
 * with {@link xpc_dictionary_get_value()}.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2
void
xpc_dictionary_set_double(xpc_object_t xdict, const char *key, double value);

/*!
 * @function xpc_dictionary_set_date
 *
 * @abstract
 * Inserts a date (primitive) value into a dictionary.
 *
 * @param xdict
 * The dictionary which is to be manipulated.
 *
 * @param key
 * The key for which the primitive value shall be set.
 *
 * @param value
 * The date value to insert. After calling this method, the XPC object
 * corresponding to the primitive value inserted may be safely retrieved with
 * {@link xpc_dictionary_get_value()}.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2
void
xpc_dictionary_set_date(xpc_object_t xdict, const char *key, int64_t value);

/*!
 * @function xpc_dictionary_set_data
 *
 * @abstract
 * Inserts a raw data value into a dictionary.
 *
 * @param xdict
 * The dictionary which is to be manipulated.
 *
 * @param key
 * The key for which the primitive value shall be set.
 *
 * @param bytes
 * The bytes to insert. After calling this method, the XPC object corresponding
 * to the primitive value inserted may be safely retrieved with
 * {@link xpc_dictionary_get_value()}.
 *
 * @param length
 * The length of the data.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2 XPC_NONNULL3
void
xpc_dictionary_set_data(xpc_object_t xdict, const char *key,
	const void *XPC_SIZEDBY(length) bytes, size_t length);

/*!
 * @function xpc_dictionary_set_string
 *
 * @abstract
 * Inserts a C string value into a dictionary.
 *
 * @param xdict
 * The dictionary which is to be manipulated.
 *
 * @param key
 * The key for which the primitive value shall be set.
 *
 * @param string
 * The C string to insert. After calling this method, the XPC object 
 * corresponding to the primitive value inserted may be safely retrieved with
 * {@link xpc_dictionary_get_value()}.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2 XPC_NONNULL3
void
xpc_dictionary_set_string(xpc_object_t xdict, const char *key,
	const char *string);

/*!
 * @function xpc_dictionary_set_uuid
 *
 * @abstract
 * Inserts a uuid (primitive) value into an array.
 *
 * @param xdict
 * The dictionary which is to be manipulated.
 *
 * @param key
 * The key for which the primitive value shall be set.
 *
 * @param uuid
 * The <code>uuid_t</code> value to insert. After calling this method, the XPC
 * object corresponding to the primitive value inserted may be safely retrieved
 * with {@link xpc_dictionary_get_value()}.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2 XPC_NONNULL3
void
xpc_dictionary_set_uuid(xpc_object_t xdict, const char *key,
	const uuid_t XPC_NONNULL_ARRAY uuid);

/*!
 * @function xpc_dictionary_set_fd
 *
 * @abstract
 * Inserts a file descriptor into a dictionary.
 *
 * @param xdict
 * The dictionary which is to be manipulated.
 *
 * @param key
 * The key for which the primitive value shall be set.
 *
 * @param fd
 * The file descriptor to insert. After calling this method, the XPC object
 * corresponding to the primitive value inserted may be safely retrieved
 * with {@link xpc_dictionary_get_value()}.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2
void
xpc_dictionary_set_fd(xpc_object_t xdict, const char *key, int fd);

/*!
 * @function xpc_dictionary_set_connection
 *
 * @abstract
 * Inserts a connection into a dictionary.
 *
 * @param xdict
 * The dictionary which is to be manipulated.
 *
 * @param key
 * The key for which the primitive value shall be set.
 *
 * @param connection
 * The connection to insert. After calling this method, the XPC object
 * corresponding to the primitive value inserted may be safely retrieved
 * with {@link xpc_dictionary_get_value()}. The connection is NOT retained by
 * the dictionary.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2 XPC_NONNULL3
void
xpc_dictionary_set_connection(xpc_object_t xdict, const char *key,
	xpc_connection_t connection);

#pragma mark Dictionary Primitive Getters
/*!
 * @function xpc_dictionary_get_bool
 *
 * @abstract
 * Gets a <code>bool</code> primitive value from a dictionary directly.
 *
 * @param xdict
 * The dictionary object which is to be examined.
 *
 * @param key
 * The key whose value is to be obtained.
 *
 * @result
 * The underlying <code>bool</code> value for the specified key. false if the
 * the value for the specified key is not a Boolean value or if there is no
 * value for the specified key.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
bool
xpc_dictionary_get_bool(xpc_object_t xdict, const char *key);

/*!
 * @function xpc_dictionary_get_int64
 *
 * @abstract
 * Gets an <code>int64</code> primitive value from a dictionary directly.
 *
 * @param xdict
 * The dictionary object which is to be examined.
 *
 * @param key
 * The key whose value is to be obtained.
 *
 * @result
 * The underlying <code>int64_t</code> value for the specified key. 0 if the
 * value for the specified key is not a signed integer value or if there is no
 * value for the specified key.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
int64_t
xpc_dictionary_get_int64(xpc_object_t xdict, const char *key);

/*!
 * @function xpc_dictionary_get_uint64
 *
 * @abstract
 * Gets a <code>uint64</code> primitive value from a dictionary directly.
 *
 * @param xdict
 * The dictionary object which is to be examined.
 *
 * @param key
 * The key whose value is to be obtained.
 *
 * @result
 * The underlying <code>uint64_t</code> value for the specified key. 0 if the
 * value for the specified key is not an unsigned integer value or if there is
 * no value for the specified key.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
uint64_t
xpc_dictionary_get_uint64(xpc_object_t xdict, const char *key);

/*!
 * @function xpc_dictionary_get_double
 *
 * @abstract
 * Gets a <code>double</code> primitive value from a dictionary directly.
 *
 * @param xdict
 * The dictionary object which is to be examined.
 *
 * @param key
 * The key whose value is to be obtained.
 *
 * @result
 * The underlying <code>double</code> value for the specified key. NAN if the
 * value for the specified key is not a floating point value or if there is no
 * value for the specified key.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
double
xpc_dictionary_get_double(xpc_object_t xdict, const char *key);

/*!
 * @function xpc_dictionary_get_date
 *
 * @abstract
 * Gets a date value from a dictionary directly.
 *
 * @param xdict
 * The dictionary object which is to be examined.
 *
 * @param key
 * The key whose value is to be obtained.
 *
 * @result
 * The underlying date interval for the specified key. 0 if the value for the
 * specified key is not a date value or if there is no value for the specified
 * key.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
int64_t
xpc_dictionary_get_date(xpc_object_t xdict, const char *key);

/*!
 * @function xpc_dictionary_get_data
 *
 * @abstract
 * Gets a raw data value from a dictionary directly.
 *
 * @param xdict
 * The dictionary object which is to be examined.
 *
 * @param key
 * The key whose value is to be obtained.
 *
 * @param length
 * For the data type, the third parameter, upon output, will contain the length
 * of the data corresponding to the specified key. May be NULL.
 *
 * @result
 * The underlying raw data for the specified key. NULL if the value for the
 * specified key is not a data value or if there is no value for the specified
 * key.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
const void * _Nullable
xpc_dictionary_get_data(xpc_object_t xdict, const char *key,
	size_t * _Nullable length);

/*!
 * @function xpc_dictionary_get_string
 *
 * @abstract
 * Gets a C string value from a dictionary directly.
 *
 * @param xdict
 * The dictionary object which is to be examined.
 *
 * @param key
 * The key whose value is to be obtained.
 *
 * @result
 * The underlying C string for the specified key. NULL if the value for the
 * specified key is not a C string value or if there is no value for the
 * specified key.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
const char * _Nullable
xpc_dictionary_get_string(xpc_object_t xdict, const char *key);

/*!
 * @function xpc_dictionary_get_uuid
 *
 * @abstract
 * Gets a uuid value from a dictionary directly.
 *
 * @param xdict
 * The dictionary object which is to be examined.
 *
 * @param key
 * The key whose value is to be obtained.
 *
 * @result
 * The underlying <code>uuid_t</code> value for the specified key. NULL is the
 * value at the specified index is not a UUID value. The returned pointer may be
 * safely passed to the uuid(3) APIs.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1 XPC_NONNULL2
const uint8_t * _Nullable
xpc_dictionary_get_uuid(xpc_object_t xdict, const char *key);

/*!
 * @function xpc_dictionary_dup_fd
 *
 * @abstract
 * Creates a file descriptor from a dictionary directly.
 *
 * @param xdict
 * The dictionary object which is to be examined.
 *
 * @param key
 * The key whose value is to be obtained.
 *
 * @result
 * A new file descriptor created from the value for the specified key. You are
 * responsible for close(2)ing this descriptor. -1 if the value for the
 * specified key is not a file descriptor value or if there is no value for the
 * specified key.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
int
xpc_dictionary_dup_fd(xpc_object_t xdict, const char *key);

/*!
 * @function xpc_dictionary_create_connection
 *
 * @abstract
 * Creates a connection from a dictionary directly.
 *
 * @param xdict
 * The dictionary object which is to be examined.
 *
 * @param key
 * The key whose value is to be obtained.
 *
 * @result
 * A new connection created from the value for the specified key. You are
 * responsible for calling xpc_release() on the returned connection. NULL if the
 * value for the specified key is not an endpoint containing a connection or if
 * there is no value for the specified key. Each call to this method for the
 * same key in the same dictionary will yield a different connection. See
 * {@link xpc_connection_create_from_endpoint()} for discussion as to the
 * responsibilities when dealing with the returned connection.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT XPC_NONNULL_ALL
xpc_connection_t _Nullable
xpc_dictionary_create_connection(xpc_object_t xdict, const char *key);

/*!
 * @function xpc_dictionary_get_dictionary
 *
 * @abstract
 * Returns the dictionary value for the specified key.
 *
 * @param xdict
 * The dictionary object which is to be examined.
 *
 * @param key
 * The key whose value is to be obtained.
 * 
 * @result
 * The object for the specified key within the dictionary. NULL if there is no
 * value associated with the specified key, if the given object was not an
 * XPC dictionary, or if the object for the specified key is not a dictionary.
 *
 * @discussion
 * This method does not grant the caller a reference to the underlying object,
 * and thus the caller is not responsible for releasing the object.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_11, __IPHONE_9_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
xpc_object_t _Nullable
xpc_dictionary_get_dictionary(xpc_object_t xdict, const char *key);

/*!
 * @function xpc_dictionary_get_array
 *
 * @abstract
 * Returns the array value for the specified key.
 *
 * @param xdict
 * The dictionary object which is to be examined.
 *
 * @param key
 * The key whose value is to be obtained.
 * 
 * @result
 * The object for the specified key within the dictionary. NULL if there is no
 * value associated with the specified key, if the given object was not an
 * XPC dictionary, or if the object for the specified key is not an array.
 *
 * @discussion
 * This method does not grant the caller a reference to the underlying object,
 * and thus the caller is not responsible for releasing the object.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_11, __IPHONE_9_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
xpc_object_t _Nullable
xpc_dictionary_get_array(xpc_object_t xdict, const char *key);

#pragma mark Runtime
/*!
 * @function xpc_main
 * The springboard into the XPCService runtime. This function will set up your
 * service bundle's listener connection and manage it automatically. After this
 * initial setup, this function will, by default, call dispatch_main(). You may
 * override this behavior by setting the RunLoopType key in your XPC service
 * bundle's Info.plist under the XPCService dictionary.
 *
 * @param handler
 * The handler with which to accept new connections.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NORETURN XPC_NONNULL1
void
xpc_main(xpc_connection_handler_t handler);

#pragma mark Transactions
/*!
 * @function xpc_transaction_begin
 * Informs the XPC runtime that a transaction has begun and that the service
 * should not exit due to inactivity.
 * 
 * @discussion
 * A service with no outstanding transactions may automatically exit due to
 * inactivity as determined by the system.
 *
 * This function may be used to manually manage transactions in cases where
 * their automatic management (as described below) does not meet the needs of an
 * XPC service. This function also updates the transaction count used for sudden
 * termination, i.e. vproc_transaction_begin(), and these two interfaces may be
 * used in combination.
 *
 * The XPC runtime will automatically begin a transaction on behalf of a service
 * when a new message is received. If no reply message is expected, the
 * transaction is automatically ended when the last reference to the message is released.
 * If a reply message is created, the transaction will end when the reply
 * message is sent or released. An XPC service may use xpc_transaction_begin()
 * and xpc_transaction_end() to inform the XPC runtime about activity that
 * occurs outside of this common pattern.
 *
 * On macOS, when the XPC runtime has determined that the service should exit,
 * the event handlers for all active peer connections will receive
 * {@link XPC_ERROR_TERMINATION_IMMINENT} as an indication that they should
 * unwind their existing transactions. After this error is delivered to a
 * connection's event handler, no more messages will be delivered to the
 * connection.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_TRANSACTION_DEPRECATED
XPC_EXPORT
void
xpc_transaction_begin(void);

/*!
 * @function xpc_transaction_end
 * Informs the XPC runtime that a transaction has ended.
 * 
 * @discussion
 * As described in {@link xpc_transaction_begin()}, this API may be used
 * interchangeably with vproc_transaction_end().
 *
 * See the discussion for {@link xpc_transaction_begin()} for details regarding
 * the XPC runtime's idle-exit policy.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_TRANSACTION_DEPRECATED
XPC_EXPORT
void
xpc_transaction_end(void);

#pragma mark XPC Event Stream
/*!
 * @function xpc_set_event_stream_handler
 * Sets the event handler to invoke when streamed events are received.
 *
 * @param stream
 * The name of the event stream for which this handler will be invoked.
 *
 * @param targetq
 * The GCD queue to which the event handler block will be submitted. This
 * parameter may be NULL, in which case the connection's target queue will be
 * libdispatch's default target queue, defined as DISPATCH_TARGET_QUEUE_DEFAULT.
 * 
 * @param handler
 * The event handler block. The event which this block receives as its first
 * parameter will always be a dictionary which contains the XPC_EVENT_KEY_NAME
 * key. The value for this key will be a string whose value is the name assigned
 * to the XPC event specified in the launchd.plist. Future keys may be added to
 * this dictionary.
 *
 * @discussion
 * Multiple calls to this function for the same event stream will result in
 * undefined behavior.
 *
 * There is no API to pause delivery of XPC events. If a process that
 * has set an XPC event handler exits, events may be dropped due to races
 * between the event handler running and the process exiting.
 */
#if __BLOCKS__
__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL3
void
xpc_set_event_stream_handler(const char *stream,
	dispatch_queue_t _Nullable targetq, xpc_handler_t handler);
#endif // __BLOCKS__ 

__END_DECLS
XPC_ASSUME_NONNULL_END

#endif // __XPC_H__