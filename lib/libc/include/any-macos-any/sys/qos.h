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

#ifndef _SYS_QOS_H
#define _SYS_QOS_H

#include <sys/cdefs.h>
#include <Availability.h>

/*!
 * @typedef qos_class_t
 *
 * @abstract
 * An abstract thread quality of service (QOS) classification.
 *
 * @discussion
 * Thread quality of service (QOS) classes are ordered abstract representations
 * of the nature of work that is expected to be performed by a pthread, dispatch
 * queue, or NSOperation. Each class specifies a maximum thread scheduling
 * priority for that band (which may be used in combination with a relative
 * priority offset within the band), as well as quality of service
 * characteristics for timer latency, CPU throughput, I/O throughput, network
 * socket traffic management behavior and more.
 *
 * A best effort is made to allocate available system resources to every QOS
 * class. Quality of service degredation only occurs during system resource
 * contention, proportionally to the QOS class. That said, QOS classes
 * representing user-initiated work attempt to achieve peak throughput while
 * QOS classes for other work attempt to achieve peak energy and thermal
 * efficiency, even in the absence of contention. Finally, the use of QOS
 * classes does not allow threads to supersede any limits that may be applied
 * to the overall process.
 */

/*!
 * @constant QOS_CLASS_USER_INTERACTIVE
 * @abstract A QOS class which indicates work performed by this thread
 * is interactive with the user.
 * @discussion Such work is requested to run at high priority relative to other
 * work on the system. Specifying this QOS class is a request to run with
 * nearly all available system CPU and I/O bandwidth even under contention.
 * This is not an energy-efficient QOS class to use for large tasks. The use of
 * this QOS class should be limited to critical interaction with the user such
 * as handling events on the main event loop, view drawing, animation, etc.
 *
 * @constant QOS_CLASS_USER_INITIATED
 * @abstract A QOS class which indicates work performed by this thread
 * was initiated by the user and that the user is likely waiting for the
 * results.
 * @discussion Such work is requested to run at a priority below critical user-
 * interactive work, but relatively higher than other work on the system. This
 * is not an energy-efficient QOS class to use for large tasks. Its use
 * should be limited to operations of short enough duration that the user is
 * unlikely to switch tasks while waiting for the results. Typical
 * user-initiated work will have progress indicated by the display of
 * placeholder content or modal user interface.
 *
 * @constant QOS_CLASS_DEFAULT
 * @abstract A default QOS class used by the system in cases where more specific
 * QOS class information is not available.
 * @discussion Such work is requested to run at a priority below critical user-
 * interactive and user-initiated work, but relatively higher than utility and
 * background tasks. Threads created by pthread_create() without an attribute
 * specifying a QOS class will default to QOS_CLASS_DEFAULT. This QOS class
 * value is not intended to be used as a work classification, it should only be
 * set when propagating or restoring QOS class values provided by the system.
 *
 * @constant QOS_CLASS_UTILITY
 * @abstract A QOS class which indicates work performed by this thread
 * may or may not be initiated by the user and that the user is unlikely to be
 * immediately waiting for the results.
 * @discussion Such work is requested to run at a priority below critical user-
 * interactive and user-initiated work, but relatively higher than low-level
 * system maintenance tasks. The use of this QOS class indicates the work
 * should be run in an energy and thermally-efficient manner. The progress of
 * utility work may or may not be indicated to the user, but the effect of such
 * work is user-visible.
 *
 * @constant QOS_CLASS_BACKGROUND
 * @abstract A QOS class which indicates work performed by this thread was not
 * initiated by the user and that the user may be unaware of the results.
 * @discussion Such work is requested to run at a priority below other work.
 * The use of this QOS class indicates the work should be run in the most energy
 * and thermally-efficient manner.
 *
 * @constant QOS_CLASS_UNSPECIFIED
 * @abstract A QOS class value which indicates the absence or removal of QOS
 * class information.
 * @discussion As an API return value, may indicate that threads or pthread
 * attributes were configured with legacy API incompatible or in conflict with
 * the QOS class system.
 */

#define __QOS_ENUM(name, type, ...) enum { __VA_ARGS__ }; typedef type name##_t
#define __QOS_CLASS_AVAILABLE(...)

#if defined(__cplusplus) || defined(__OBJC__) || __LP64__
#if defined(__has_feature) && defined(__has_extension)
#if __has_feature(objc_fixed_enum) || __has_extension(cxx_strong_enums)
#undef __QOS_ENUM
#define __QOS_ENUM(name, type, ...) typedef enum : type { __VA_ARGS__ } name##_t
#endif
#endif
#if __has_feature(enumerator_attributes)
#undef __QOS_CLASS_AVAILABLE
#define __QOS_CLASS_AVAILABLE __API_AVAILABLE
#endif
#endif

__QOS_ENUM(qos_class, unsigned int,
	QOS_CLASS_USER_INTERACTIVE
			__QOS_CLASS_AVAILABLE(macos(10.10), ios(8.0)) = 0x21,
	QOS_CLASS_USER_INITIATED
			__QOS_CLASS_AVAILABLE(macos(10.10), ios(8.0)) = 0x19,
	QOS_CLASS_DEFAULT
			__QOS_CLASS_AVAILABLE(macos(10.10), ios(8.0)) = 0x15,
	QOS_CLASS_UTILITY
			__QOS_CLASS_AVAILABLE(macos(10.10), ios(8.0)) = 0x11,
	QOS_CLASS_BACKGROUND
			__QOS_CLASS_AVAILABLE(macos(10.10), ios(8.0)) = 0x09,
	QOS_CLASS_UNSPECIFIED
			__QOS_CLASS_AVAILABLE(macos(10.10), ios(8.0)) = 0x00,
);

#undef __QOS_ENUM

/*!
 * @constant QOS_MIN_RELATIVE_PRIORITY
 * @abstract The minimum relative priority that may be specified within a
 * QOS class. These priorities are relative only within a given QOS class
 * and meaningful only for the current process.
 */
#define QOS_MIN_RELATIVE_PRIORITY (-15)

/* Userspace (only) definitions */

#ifndef KERNEL

__BEGIN_DECLS

/*!
 * @function qos_class_self
 *
 * @abstract
 * Returns the requested QOS class of the current thread.
 *
 * @return
 * One of the QOS class values in qos_class_t.
 */
__API_AVAILABLE(macos(10.10), ios(8.0))
qos_class_t
qos_class_self(void);

/*!
 * @function qos_class_main
 *
 * @abstract
 * Returns the initial requested QOS class of the main thread.
 *
 * @discussion
 * The QOS class that the main thread of a process is created with depends on
 * the type of process (e.g. application or daemon) and on how it has been
 * launched.
 *
 * This function returns that initial requested QOS class value chosen by the
 * system to enable propagation of that classification to matching work not
 * executing on the main thread.
 *
 * @return
 * One of the QOS class values in qos_class_t.
 */
__API_AVAILABLE(macos(10.10), ios(8.0))
qos_class_t
qos_class_main(void);

__END_DECLS

#endif // KERNEL

#endif // _SYS_QOS_H