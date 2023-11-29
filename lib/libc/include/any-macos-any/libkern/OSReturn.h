/*
 * Copyright (c) 2000 Apple Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */
/*
 * Copyright (c) 1998 Apple Inc.  All rights reserved.
 *
 * HISTORY
 *
 */

/*
 * Core OSReturn values.
 */

#ifndef __LIBKERN_OSRETURN_H
#define __LIBKERN_OSRETURN_H

#include <sys/cdefs.h>

#include <mach/error.h>

__BEGIN_DECLS


/*!
 * @header
 *
 * Declares functions, basic return values, and other constants
 * related to kernel extensions (kexts).
 */

#if PRAGMA_MARK
#pragma mark Core OSReturn Values for Libkern
#endif
/*********************************************************************
* Core OSReturn Values for Libkern
*********************************************************************/
/*!
 * @group Core OSReturn Values for Libkern
 * Some kext and I/O Kit functions can return these values,
 * as well as  other values of
 * <code>kern_return_t</code>.
 *
 * Many of these return values represent internal errors
 * in the Libkern C++ run-time typing information system
 * based on @link //apple_ref/doc/class/OSMetaClass OSMetaClass@/link;
 * you are unlikely to ever see them.
 *
 */


/*!
 * @typedef  OSReturn
 * @abstract The return type for many Libkern functions.
 */
typedef kern_return_t OSReturn;

#ifndef sys_libkern
#define sys_libkern                   err_system(0x37)
#endif /* sys_libkern */

#define sub_libkern_common            err_sub(0)
#define sub_libkern_metaclass         err_sub(1)
#define sub_libkern_reserved          err_sub(-1)

#define libkern_common_err(return )    (sys_libkern|sub_libkern_common|(return))
#define libkern_metaclass_err(return ) (sys_libkern|sub_libkern_metaclass|(return))

/* See OSKextLib.h for these
 * #define sub_libkern_kext           err_sub(2)
 * #define libkern_kext_err(code)     (sys_libkern|sub_libkern_kext|(code))
 */

/*!
 * @define   kOSReturnSuccess
 * @abstract Operation successful.
 *           Equal to <code>@link //apple_ref/c/econst/KERN_SUCCESS
 *           KERN_SUCCESS@/link</code>.
 */
#define kOSReturnSuccess              KERN_SUCCESS

/*!
 * @define   kOSReturnError
 * @abstract Unspecified Libkern error.
 *           <b>Not equal</b> to
 *           <code>@link //apple_ref/c/econst/KERN_FAILURE
 *           KERN_FAILURE@/link</code>.
 */
#define kOSReturnError                libkern_common_err(1)

/*!
 * @define   kOSMetaClassInternal
 * @abstract Internal OSMetaClass run-time error.
 */
#define kOSMetaClassInternal          libkern_metaclass_err(1)

/*!
 * @define   kOSMetaClassHasInstances
 * @abstract A kext cannot be unloaded because there are instances
 *           derived from Libkern C++ classes that it defines.
 */
#define kOSMetaClassHasInstances      libkern_metaclass_err(2)

/*!
 * @define   kOSMetaClassNoInit
 * @abstract Internal error: The Libkern C++ class registration system
 *           was not properly initialized during kext loading.
 */
#define kOSMetaClassNoInit            libkern_metaclass_err(3)
// OSMetaClass::preModLoad wasn't called, runtime internal error

/*!
 * @define   kOSMetaClassNoTempData
 * @abstract Internal error: An allocation failure occurred
 *           registering Libkern C++ classes during kext loading.
 */
#define kOSMetaClassNoTempData        libkern_metaclass_err(4)
// Allocation failure internal data

/*!
 * @define   kOSMetaClassNoDicts
 * @abstract Internal error: An allocation failure occurred
 *           registering Libkern C++ classes during kext loading.
 */
#define kOSMetaClassNoDicts           libkern_metaclass_err(5)
// Allocation failure for Metaclass internal dictionaries

/*!
 * @define   kOSMetaClassNoKModSet
 * @abstract Internal error: An allocation failure occurred
 *           registering Libkern C++ classes during kext loading.
 */
#define kOSMetaClassNoKModSet         libkern_metaclass_err(6)
// Allocation failure for internal kmodule set

/*!
 * @define   kOSMetaClassNoInsKModSet
 * @abstract Internal error: An error occurred registering
 *           a specific Libkern C++ class during kext loading.
 */
#define kOSMetaClassNoInsKModSet      libkern_metaclass_err(7)
// Can't insert the KMod set into the module dictionary

/*!
 * @define   kOSMetaClassNoSuper
 * @abstract Internal error: No superclass can be found
 *           for a specific Libkern C++ class during kext loading.
 */
#define kOSMetaClassNoSuper           libkern_metaclass_err(8)

/*!
 * @define   kOSMetaClassInstNoSuper
 * @abstract Internal error: No superclass can be found when constructing
 *           an instance of a Libkern C++ class.
 */
#define kOSMetaClassInstNoSuper       libkern_metaclass_err(9)

/*!
 * @define   kOSMetaClassDuplicateClass
 * @abstract A duplicate Libkern C++ classname was encountered
 *           during kext loading.
 */
#define kOSMetaClassDuplicateClass    libkern_metaclass_err(10)

/*!
 * @define   kOSMetaClassNoKext
 * @abstract Internal error: The kext for a Libkern C++ class
 *           can't be found during kext loading.
 */
#define kOSMetaClassNoKext            libkern_metaclass_err(11)

__END_DECLS

#endif /* ! __LIBKERN_OSRETURN_H */
