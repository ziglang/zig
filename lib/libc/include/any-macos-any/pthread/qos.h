/*
 * Copyright (c) 2013-2014 Apple Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_LICENSE_HEADER_END@
 */

#ifndef _PTHREAD_QOS_H
#define _PTHREAD_QOS_H

#include <sys/cdefs.h>
#include <sys/_pthread/_pthread_attr_t.h> /* pthread_attr_t */
#include <sys/_pthread/_pthread_t.h>      /* pthread_t */
#include <Availability.h>

#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL

#include <sys/qos.h>

#ifndef KERNEL

#if __has_feature(assume_nonnull)
_Pragma("clang assume_nonnull begin")
#endif
__BEGIN_DECLS

/*!
 * @function pthread_attr_set_qos_class_np
 *
 * @abstract
 * Sets the QOS class and relative priority of a pthread attribute structure
 * which may be used to specify the requested QOS class of newly created
 * threads.
 *
 * @discussion
 * The QOS class and relative priority represent an overall combination of
 * system quality of service attributes on a thread.
 *
 * Subsequent calls to interfaces such as pthread_attr_setschedparam() that are
 * incompatible or in conflict with the QOS class system will unset the QOS
 * class requested with this interface and pthread_attr_get_qos_class_np() will
 * return QOS_CLASS_UNSPECIFIED.
 *
 * @param __attr
 * The pthread attribute structure to modify.
 *
 * @param __qos_class
 * A QOS class value:
 *	- QOS_CLASS_USER_INTERACTIVE
 *	- QOS_CLASS_USER_INITIATED
 *	- QOS_CLASS_DEFAULT
 *	- QOS_CLASS_UTILITY
 *	- QOS_CLASS_BACKGROUND
 * EINVAL will be returned if any other value is provided.
 *
 * @param __relative_priority
 * A relative priority within the QOS class. This value is a negative offset
 * from the maximum supported scheduler priority for the given class.
 * EINVAL will be returned if the value is greater than zero or less than
 * QOS_MIN_RELATIVE_PRIORITY.
 *
 * @return
 * Zero if successful, otherwise an errno value.
 */
__API_AVAILABLE(macos(10.10), ios(8.0))
int
pthread_attr_set_qos_class_np(pthread_attr_t *__attr,
		qos_class_t __qos_class, int __relative_priority);

/*!
 * @function pthread_attr_get_qos_class_np
 *
 * @abstract
 * Gets the QOS class and relative priority of a pthread attribute structure.
 *
 * @param __attr
 * The pthread attribute structure to inspect.
 *
 * @param __qos_class
 * On output, a QOS class value:
 *	- QOS_CLASS_USER_INTERACTIVE
 *	- QOS_CLASS_USER_INITIATED
 *	- QOS_CLASS_DEFAULT
 *	- QOS_CLASS_UTILITY
 *	- QOS_CLASS_BACKGROUND
 *	- QOS_CLASS_UNSPECIFIED
 * This value may be NULL in which case no value is returned.
 *
 * @param __relative_priority
 * On output, a relative priority offset within the QOS class.
 * This value may be NULL in which case no value is returned.
 *
 * @return
 * Zero if successful, otherwise an errno value.
 */
__API_AVAILABLE(macos(10.10), ios(8.0))
int
pthread_attr_get_qos_class_np(pthread_attr_t * __restrict __attr,
		qos_class_t * _Nullable __restrict __qos_class,
		int * _Nullable __restrict __relative_priority);

/*!
 * @function pthread_set_qos_class_self_np
 *
 * @abstract
 * Sets the requested QOS class and relative priority of the current thread.
 *
 * @discussion
 * The QOS class and relative priority represent an overall combination of
 * system quality of service attributes on a thread.
 *
 * Subsequent calls to interfaces such as pthread_setschedparam() that are
 * incompatible or in conflict with the QOS class system will unset the QOS
 * class requested with this interface and pthread_get_qos_class_np() will
 * return QOS_CLASS_UNSPECIFIED thereafter. A thread so modified is permanently
 * opted-out of the QOS class system and calls to this function to request a QOS
 * class for such a thread will fail and return EPERM.
 *
 * @param __qos_class
 * A QOS class value:
 *	- QOS_CLASS_USER_INTERACTIVE
 *	- QOS_CLASS_USER_INITIATED
 *	- QOS_CLASS_DEFAULT
 *	- QOS_CLASS_UTILITY
 *	- QOS_CLASS_BACKGROUND
 * EINVAL will be returned if any other value is provided.
 *
 * @param __relative_priority
 * A relative priority within the QOS class. This value is a negative offset
 * from the maximum supported scheduler priority for the given class.
 * EINVAL will be returned if the value is greater than zero or less than
 * QOS_MIN_RELATIVE_PRIORITY.
 *
 * @return
 * Zero if successful, otherwise an errno value.
 */
__API_AVAILABLE(macos(10.10), ios(8.0))
int
pthread_set_qos_class_self_np(qos_class_t __qos_class,
		int __relative_priority);

/*!
 * @function pthread_get_qos_class_np
 *
 * @abstract
 * Gets the requested QOS class and relative priority of a thread.
 *
 * @param __pthread
 * The target thread to inspect.
 *
 * @param __qos_class
 * On output, a QOS class value:
 *	- QOS_CLASS_USER_INTERACTIVE
 *	- QOS_CLASS_USER_INITIATED
 *	- QOS_CLASS_DEFAULT
 *	- QOS_CLASS_UTILITY
 *	- QOS_CLASS_BACKGROUND
 *	- QOS_CLASS_UNSPECIFIED
 * This value may be NULL in which case no value is returned.
 *
 * @param __relative_priority
 * On output, a relative priority offset within the QOS class.
 * This value may be NULL in which case no value is returned.
 *
 * @return
 * Zero if successful, otherwise an errno value.
 */
__API_AVAILABLE(macos(10.10), ios(8.0))
int
pthread_get_qos_class_np(pthread_t __pthread,
		qos_class_t * _Nullable __restrict __qos_class,
		int * _Nullable __restrict __relative_priority);

/*!
 * @typedef pthread_override_t
 *
 * @abstract
 * An opaque object representing a QOS class override of a thread.
 *
 * @discussion
 * A QOS class override of a target thread expresses that an item of pending
 * work classified with a specific QOS class and relative priority depends on
 * the completion of the work currently being executed by the thread (e.g. due
 * to ordering requirements).
 *
 * While overrides are in effect, the target thread will execute at the maximum
 * QOS class and relative priority of all overrides and of the QOS class
 * requested by the thread itself.
 *
 * A QOS class override does not modify the target thread's requested QOS class
 * value and the effect of an override is not visible to the qos_class_self()
 * and pthread_get_qos_class_np() interfaces.
 */

typedef struct pthread_override_s* pthread_override_t;

/*!
 * @function pthread_override_qos_class_start_np
 *
 * @abstract
 * Starts a QOS class override of the specified target thread.
 *
 * @discussion
 * Starting a QOS class override of the specified target thread expresses that
 * an item of pending work classified with the specified QOS class and relative
 * priority depends on the completion of the work currently being executed by
 * the thread (e.g. due to ordering requirements).
 *
 * While overrides are in effect, the specified target thread will execute at
 * the maximum QOS class and relative priority of all overrides and of the QOS
 * class requested by the thread itself.
 *
 * Starting a QOS class override does not modify the target thread's requested
 * QOS class value and the effect of an override is not visible to the
 * qos_class_self() and pthread_get_qos_class_np() interfaces.
 *
 * The returned newly allocated override object is intended to be associated
 * with the item of pending work in question. Once the dependency has been
 * satisfied and enabled that work to begin executing, the QOS class override
 * must be ended by passing the associated override object to
 * pthread_override_qos_class_end_np(). Failure to do so will result in the
 * associated resources to be leaked and the target thread to be permanently
 * executed at an inappropriately elevated QOS class.
 *
 * @param __pthread
 * The target thread to modify.
 *
 * @param __qos_class
 * A QOS class value:
 *	- QOS_CLASS_USER_INTERACTIVE
 *	- QOS_CLASS_USER_INITIATED
 *	- QOS_CLASS_DEFAULT
 *	- QOS_CLASS_UTILITY
 *	- QOS_CLASS_BACKGROUND
 * NULL will be returned if any other value is provided.
 *
 * @param __relative_priority
 * A relative priority within the QOS class. This value is a negative offset
 * from the maximum supported scheduler priority for the given class.
 * NULL will be returned if the value is greater than zero or less than
 * QOS_MIN_RELATIVE_PRIORITY.
 *
 * @return
 * A newly allocated override object if successful, or NULL if the override
 * could not be started.
 */
__API_AVAILABLE(macos(10.10), ios(8.0))
pthread_override_t
pthread_override_qos_class_start_np(pthread_t __pthread,
		qos_class_t __qos_class, int __relative_priority);

/*!
 * @function pthread_override_qos_class_end_np
 *
 * @abstract
 * Ends a QOS class override.
 *
 * @discussion
 * Passing an override object returned by pthread_override_qos_class_start_np()
 * ends the QOS class override started by that call and deallocates all
 * associated resources as well as the override object itself.
 *
 * The thread starting and the thread ending a QOS class override need not be
 * identical. If the thread ending the override is the the target thread of the
 * override itself, it should take care to elevate its requested QOS class
 * appropriately with pthread_set_qos_class_self_np() before ending the
 * override.
 *
 * @param __override
 * An override object returned by pthread_override_qos_class_start_np().
 *
 * @return
 * Zero if successful, otherwise an errno value.
 */
__API_AVAILABLE(macos(10.10), ios(8.0))
int
pthread_override_qos_class_end_np(pthread_override_t __override);

__END_DECLS
#if __has_feature(assume_nonnull)
_Pragma("clang assume_nonnull end")
#endif

#endif // KERNEL

#endif // __DARWIN_C_LEVEL >= __DARWIN_C_FULL

#endif // _PTHREAD_QOS_H
