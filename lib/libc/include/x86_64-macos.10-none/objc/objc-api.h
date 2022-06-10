/*
 * Copyright (c) 1999-2006 Apple Inc.  All Rights Reserved.
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
// Copyright 1988-1996 NeXT Software, Inc.

#ifndef _OBJC_OBJC_API_H_
#define _OBJC_OBJC_API_H_

#include <Availability.h>
#include <AvailabilityMacros.h>
#include <TargetConditionals.h>
#include <sys/types.h>

#ifndef __has_feature
#   define __has_feature(x) 0
#endif

#ifndef __has_extension
#   define __has_extension __has_feature
#endif

#ifndef __has_attribute
#   define __has_attribute(x) 0
#endif

#if !__has_feature(nullability)
#   ifndef _Nullable
#       define _Nullable
#   endif
#   ifndef _Nonnull
#       define _Nonnull
#   endif
#   ifndef _Null_unspecified
#       define _Null_unspecified
#   endif
#endif



/*
 * OBJC_API_VERSION 0 or undef: Tiger and earlier API only
 * OBJC_API_VERSION 2: Leopard and later API available
 */
#if !defined(OBJC_API_VERSION)
#   if defined(__MAC_OS_X_VERSION_MIN_REQUIRED)  &&  __MAC_OS_X_VERSION_MIN_REQUIRED < __MAC_10_5
#       define OBJC_API_VERSION 0
#   else
#       define OBJC_API_VERSION 2
#   endif
#endif


/*
 * OBJC_NO_GC 1: GC is not supported
 * OBJC_NO_GC undef: GC is supported. This SDK no longer supports this mode.
 *
 * OBJC_NO_GC_API undef: Libraries must export any symbols that 
 *                       dual-mode code may links to.
 * OBJC_NO_GC_API 1: Libraries need not export GC-related symbols.
 */
#if defined(__OBJC_GC__)
#   error Objective-C garbage collection is not supported.
#elif TARGET_OS_OSX
    /* GC is unsupported. GC API symbols are exported. */
#   define OBJC_NO_GC 1
#   undef  OBJC_NO_GC_API
#else
    /* GC is unsupported. GC API symbols are not exported. */
#   define OBJC_NO_GC 1
#   define OBJC_NO_GC_API 1
#endif


/* NS_ENFORCE_NSOBJECT_DESIGNATED_INITIALIZER == 1 
 * marks -[NSObject init] as a designated initializer. */
#if !defined(NS_ENFORCE_NSOBJECT_DESIGNATED_INITIALIZER)
#   define NS_ENFORCE_NSOBJECT_DESIGNATED_INITIALIZER 1
#endif


/* OBJC_OLD_DISPATCH_PROTOTYPES == 0 enforces the rule that the dispatch 
 * functions must be cast to an appropriate function pointer type. */
#if !defined(OBJC_OLD_DISPATCH_PROTOTYPES)
#   if __swift__
        // Existing Swift code expects IMP to be Comparable.
        // Variadic IMP is comparable via OpaquePointer; non-variadic IMP isn't.
#       define OBJC_OLD_DISPATCH_PROTOTYPES 1
#   else
#       define OBJC_OLD_DISPATCH_PROTOTYPES 0
#   endif
#endif


/* OBJC_AVAILABLE: shorthand for all-OS availability */

#   if !defined(OBJC_AVAILABLE)
#       define OBJC_AVAILABLE(x, i, t, w, b)                            \
            __OSX_AVAILABLE(x)  __IOS_AVAILABLE(i)  __TVOS_AVAILABLE(t) \
            __WATCHOS_AVAILABLE(w)
#   endif



/* OBJC_OSX_DEPRECATED_OTHERS_UNAVAILABLE: Deprecated on OS X,
 * unavailable everywhere else. */

#   if !defined(OBJC_OSX_DEPRECATED_OTHERS_UNAVAILABLE)
#       define OBJC_OSX_DEPRECATED_OTHERS_UNAVAILABLE(_start, _dep, _msg) \
            __OSX_DEPRECATED(_start, _dep, _msg)                          \
            __IOS_UNAVAILABLE __TVOS_UNAVAILABLE                          \
            __WATCHOS_UNAVAILABLE
#   endif



/* OBJC_OSX_AVAILABLE_OTHERS_UNAVAILABLE: Available on OS X,
 * unavailable everywhere else. */

#   if !defined(OBJC_OSX_AVAILABLE_OTHERS_UNAVAILABLE)
#       define OBJC_OSX_AVAILABLE_OTHERS_UNAVAILABLE(vers) \
            __OSX_AVAILABLE(vers)                          \
            __IOS_UNAVAILABLE __TVOS_UNAVAILABLE           \
            __WATCHOS_UNAVAILABLE
#    endif



/* OBJC_ISA_AVAILABILITY: `isa` will be deprecated or unavailable 
 * in the future */
#if !defined(OBJC_ISA_AVAILABILITY)
#   if __OBJC2__
#       define OBJC_ISA_AVAILABILITY  __attribute__((deprecated))
#   else
#       define OBJC_ISA_AVAILABILITY  /* still available */
#   endif
#endif


/* OBJC2_UNAVAILABLE: unavailable in objc 2.0, deprecated in Leopard */
#if !defined(OBJC2_UNAVAILABLE)
#   if __OBJC2__
#       define OBJC2_UNAVAILABLE UNAVAILABLE_ATTRIBUTE
#   else
        /* plain C code also falls here, but this is close enough */
#       define OBJC2_UNAVAILABLE                                       \
            __OSX_DEPRECATED(10.5, 10.5, "not available in __OBJC2__") \
            __IOS_DEPRECATED(2.0, 2.0, "not available in __OBJC2__")   \
            __TVOS_UNAVAILABLE __WATCHOS_UNAVAILABLE 
#   endif
#endif

/* OBJC_UNAVAILABLE: unavailable, with a message where supported */
#if !defined(OBJC_UNAVAILABLE)
#   if __has_extension(attribute_unavailable_with_message)
#       define OBJC_UNAVAILABLE(_msg) __attribute__((unavailable(_msg)))
#   else
#       define OBJC_UNAVAILABLE(_msg) __attribute__((unavailable))
#   endif
#endif

/* OBJC_DEPRECATED: deprecated, with a message where supported */
#if !defined(OBJC_DEPRECATED)
#   if __has_extension(attribute_deprecated_with_message)
#       define OBJC_DEPRECATED(_msg) __attribute__((deprecated(_msg)))
#   else
#       define OBJC_DEPRECATED(_msg) __attribute__((deprecated))
#   endif
#endif

/* OBJC_ARC_UNAVAILABLE: unavailable with -fobjc-arc */
#if !defined(OBJC_ARC_UNAVAILABLE)
#   if __has_feature(objc_arc)
#       define OBJC_ARC_UNAVAILABLE OBJC_UNAVAILABLE("not available in automatic reference counting mode")
#   else
#       define OBJC_ARC_UNAVAILABLE
#   endif
#endif

/* OBJC_SWIFT_UNAVAILABLE: unavailable in Swift */
#if !defined(OBJC_SWIFT_UNAVAILABLE)
#   if __has_feature(attribute_availability_swift)
#       define OBJC_SWIFT_UNAVAILABLE(_msg) __attribute__((availability(swift, unavailable, message=_msg)))
#   else
#       define OBJC_SWIFT_UNAVAILABLE(_msg)
#   endif
#endif

/* OBJC_ARM64_UNAVAILABLE: unavailable on arm64 (i.e. stret dispatch) */
#if !defined(OBJC_ARM64_UNAVAILABLE)
#   if defined(__arm64__)
#       define OBJC_ARM64_UNAVAILABLE OBJC_UNAVAILABLE("not available in arm64")
#   else
#       define OBJC_ARM64_UNAVAILABLE 
#   endif
#endif

/* OBJC_GC_UNAVAILABLE: unavailable with -fobjc-gc or -fobjc-gc-only */
#if !defined(OBJC_GC_UNAVAILABLE)
#   define OBJC_GC_UNAVAILABLE
#endif

#if !defined(OBJC_EXTERN)
#   if defined(__cplusplus)
#       define OBJC_EXTERN extern "C" 
#   else
#       define OBJC_EXTERN extern
#   endif
#endif

#if !defined(OBJC_VISIBLE)

#       define OBJC_VISIBLE  __attribute__((visibility("default")))

#endif

#if !defined(OBJC_EXPORT)
#   define OBJC_EXPORT  OBJC_EXTERN OBJC_VISIBLE
#endif

#if !defined(OBJC_IMPORT)
#   define OBJC_IMPORT extern
#endif

#if !defined(OBJC_ROOT_CLASS)
#   if __has_attribute(objc_root_class)
#       define OBJC_ROOT_CLASS __attribute__((objc_root_class))
#   else
#       define OBJC_ROOT_CLASS
#   endif
#endif

#ifndef __DARWIN_NULL
#define __DARWIN_NULL NULL
#endif

#if !defined(OBJC_INLINE)
#   define OBJC_INLINE __inline
#endif

// Declares an enum type or option bits type as appropriate for each language.
#if (__cplusplus && __cplusplus >= 201103L && (__has_extension(cxx_strong_enums) || __has_feature(objc_fixed_enum))) || (!__cplusplus && __has_feature(objc_fixed_enum))
#define OBJC_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#if (__cplusplus)
#define OBJC_OPTIONS(_type, _name) _type _name; enum : _type
#else
#define OBJC_OPTIONS(_type, _name) enum _name : _type _name; enum _name : _type
#endif
#else
#define OBJC_ENUM(_type, _name) _type _name; enum
#define OBJC_OPTIONS(_type, _name) _type _name; enum
#endif

#if !defined(OBJC_RETURNS_RETAINED)
#   if __OBJC__ && __has_attribute(ns_returns_retained)
#       define OBJC_RETURNS_RETAINED __attribute__((ns_returns_retained))
#   else
#       define OBJC_RETURNS_RETAINED
#   endif
#endif

#endif