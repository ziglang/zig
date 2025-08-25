// Copyright (c) 2009-2011 Apple Inc. All rights reserved.

#ifndef __XPC_BASE_H__
#define __XPC_BASE_H__

#include <sys/cdefs.h>

#if !defined(__has_include)
#define __has_include(x) 0
#endif // !defined(__has_include)

#if !defined(__has_attribute)
#define __has_attribute(x) 0
#endif // !defined(__has_attribute)

#if !defined(__has_feature)
#define __has_feature(x) 0
#endif // !defined(__has_feature)

#if !defined(__has_extension)
#define __has_extension(x) 0
#endif // !defined(__has_extension)

#if __has_include(<xpc/availability.h>)
#include <xpc/availability.h>
#else // __has_include(<xpc/availability.h>)
#include <Availability.h>
#endif // __has_include(<xpc/availability.h>)

#include <os/availability.h>

#ifndef __XPC_INDIRECT__
#error "Please #include <xpc/xpc.h> instead of this file directly."
#endif // __XPC_INDIRECT__ 

__BEGIN_DECLS

#pragma mark Attribute Shims
#ifdef __GNUC__
#define XPC_CONSTRUCTOR __attribute__((constructor))
#define XPC_NORETURN __attribute__((__noreturn__))
#define XPC_NOTHROW __attribute__((__nothrow__))
#define XPC_NONNULL1 __attribute__((__nonnull__(1)))
#define XPC_NONNULL2 __attribute__((__nonnull__(2)))
#define XPC_NONNULL3 __attribute__((__nonnull__(3)))
#define XPC_NONNULL4 __attribute__((__nonnull__(4)))
#define XPC_NONNULL5 __attribute__((__nonnull__(5)))
#define XPC_NONNULL6 __attribute__((__nonnull__(6)))
#define XPC_NONNULL7 __attribute__((__nonnull__(7)))
#define XPC_NONNULL8 __attribute__((__nonnull__(8)))
#define XPC_NONNULL9 __attribute__((__nonnull__(9)))
#define XPC_NONNULL10 __attribute__((__nonnull__(10)))
#define XPC_NONNULL11 __attribute__((__nonnull__(11)))
#define XPC_NONNULL_ALL __attribute__((__nonnull__))
#define XPC_SENTINEL __attribute__((__sentinel__))
#define XPC_PURE __attribute__((__pure__))
#define XPC_WARN_RESULT __attribute__((__warn_unused_result__))
#define XPC_MALLOC __attribute__((__malloc__))
#define XPC_UNUSED __attribute__((__unused__))
#define XPC_USED __attribute__((__used__))
#define XPC_PACKED __attribute__((__packed__))
#define XPC_PRINTF(m, n) __attribute__((format(printf, m, n)))
#define XPC_INLINE static __inline__ __attribute__((__always_inline__))
#define XPC_NOINLINE __attribute__((noinline))
#define XPC_NOIMPL __attribute__((unavailable))

#if __has_attribute(noescape)
#define XPC_NOESCAPE __attribute__((__noescape__))
#else
#define XPC_NOESCAPE
#endif

#if __has_extension(attribute_unavailable_with_message)
#define XPC_UNAVAILABLE(m) __attribute__((unavailable(m)))
#else // __has_extension(attribute_unavailable_with_message)
#define XPC_UNAVAILABLE(m) XPC_NOIMPL
#endif // __has_extension(attribute_unavailable_with_message)

#define XPC_EXPORT extern __attribute__((visibility("default")))
#define XPC_NOEXPORT __attribute__((visibility("hidden")))
#define XPC_WEAKIMPORT extern __attribute__((weak_import))
#define XPC_DEBUGGER_EXCL XPC_NOEXPORT XPC_USED
#define XPC_TRANSPARENT_UNION __attribute__((transparent_union))
#if __clang__
#define XPC_DEPRECATED(m) __attribute__((deprecated(m)))
#else // __clang__
#define XPC_DEPRECATED(m) __attribute__((deprecated))
#endif // __clang
#ifndef XPC_TESTEXPORT
#define XPC_TESTEXPORT XPC_NOEXPORT
#endif // XPC_TESTEXPORT

#if defined(__XPC_TEST__) && __XPC_TEST__
#define XPC_TESTSTATIC
#define XPC_TESTEXTERN extern
#else // defined(__XPC_TEST__) && __XPC_TEST__
#define XPC_TESTSTATIC static
#endif // defined(__XPC_TEST__) && __XPC_TEST__

#if __has_feature(objc_arc)
#define XPC_GIVES_REFERENCE __strong
#define XPC_UNRETAINED __unsafe_unretained
#define XPC_BRIDGE(xo) ((__bridge void *)(xo))
#define XPC_BRIDGEREF_BEGIN(xo) ((__bridge_retained void *)(xo))
#define XPC_BRIDGEREF_BEGIN_WITH_REF(xo) ((__bridge void *)(xo))
#define XPC_BRIDGEREF_MIDDLE(xo) ((__bridge id)(xo))
#define XPC_BRIDGEREF_END(xo) ((__bridge_transfer id)(xo))
#else // __has_feature(objc_arc)
#define XPC_GIVES_REFERENCE
#define XPC_UNRETAINED
#define XPC_BRIDGE(xo) (xo)
#define XPC_BRIDGEREF_BEGIN(xo) (xo)
#define XPC_BRIDGEREF_BEGIN_WITH_REF(xo) (xo)
#define XPC_BRIDGEREF_MIDDLE(xo) (xo)
#define XPC_BRIDGEREF_END(xo) (xo)
#endif // __has_feature(objc_arc)

#define _xpc_unreachable() __builtin_unreachable()
#else // __GNUC__ 
/*! @parseOnly */
#define XPC_CONSTRUCTOR
/*! @parseOnly */
#define XPC_NORETURN
/*! @parseOnly */
#define XPC_NOTHROW
/*! @parseOnly */
#define XPC_NONNULL1
/*! @parseOnly */
#define XPC_NONNULL2
/*! @parseOnly */
#define XPC_NONNULL3
/*! @parseOnly */
#define XPC_NONNULL4
/*! @parseOnly */
#define XPC_NONNULL5
/*! @parseOnly */
#define XPC_NONNULL6
/*! @parseOnly */
#define XPC_NONNULL7
/*! @parseOnly */
#define XPC_NONNULL8
/*! @parseOnly */
#define XPC_NONNULL9
/*! @parseOnly */
#define XPC_NONNULL10
/*! @parseOnly */
#define XPC_NONNULL11
/*! @parseOnly */
#define XPC_NONNULL(n)
/*! @parseOnly */
#define XPC_NONNULL_ALL
/*! @parseOnly */
#define XPC_SENTINEL
/*! @parseOnly */
#define XPC_PURE
/*! @parseOnly */
#define XPC_WARN_RESULT
/*! @parseOnly */
#define XPC_MALLOC
/*! @parseOnly */
#define XPC_UNUSED
/*! @parseOnly */
#define XPC_PACKED
/*! @parseOnly */
#define XPC_PRINTF(m, n)
/*! @parseOnly */
#define XPC_INLINE static inline
/*! @parseOnly */
#define XPC_NOINLINE
/*! @parseOnly */
#define XPC_NOIMPL
/*! @parseOnly */
#define XPC_EXPORT extern
/*! @parseOnly */
#define XPC_WEAKIMPORT
/*! @parseOnly */
#define XPC_DEPRECATED
/*! @parseOnly */
#define XPC_UNAVAILABLE(m)
/*! @parseOnly */
#define XPC_NOESCAPE
#endif // __GNUC__

#if __has_feature(assume_nonnull)
#define XPC_ASSUME_NONNULL_BEGIN _Pragma("clang assume_nonnull begin")
#define XPC_ASSUME_NONNULL_END   _Pragma("clang assume_nonnull end")
#else
#define XPC_ASSUME_NONNULL_BEGIN
#define XPC_ASSUME_NONNULL_END
#endif

#if __has_feature(nullability_on_arrays)
#define XPC_NONNULL_ARRAY _Nonnull
#else
#define XPC_NONNULL_ARRAY
#endif

#if defined(__has_ptrcheck) && __has_ptrcheck
#define XPC_PTR_ASSUMES_SINGLE __ptrcheck_abi_assume_single()
#define XPC_SINGLE __single
#define XPC_UNSAFE_INDEXABLE __unsafe_indexable
#define XPC_CSTRING XPC_UNSAFE_INDEXABLE
#define XPC_SIZEDBY(N) __sized_by(N)
#define XPC_COUNTEDBY(N) __counted_by(N)
#define XPC_UNSAFE_FORGE_SIZED_BY(_type, _ptr, _size) \
		__unsafe_forge_bidi_indexable(_type, _ptr, _size)
#define XPC_UNSAFE_FORGE_SINGLE(_type, _ptr) \
		__unsafe_forge_single(_type, _ptr)
#else // defined(__has_ptrcheck) ** __has_ptrcheck
#define XPC_PTR_ASSUMES_SINGLE
#define XPC_SINGLE
#define XPC_UNSAFE_INDEXABLE
#define XPC_CSTRING
#define XPC_SIZEDBY(N)
#define XPC_COUNTEDBY(N)
#define XPC_UNSAFE_FORGE_SIZED_BY(_type, _ptr, _size) ((_type)(_ptr))
#define XPC_UNSAFE_FORGE_SINGLE(_type, _ptr) ((_type)(_ptr))
#endif // defined(__has_ptrcheck) ** __has_ptrcheck

#ifdef OS_CLOSED_OPTIONS
#define XPC_FLAGS_ENUM(_name, _type, ...) \
		OS_CLOSED_OPTIONS(_name, _type, __VA_ARGS__)
#else // OS_CLOSED_ENUM
#define XPC_FLAGS_ENUM(_name, _type, ...) \
		OS_ENUM(_name, _type, __VA_ARGS__)
#endif // OS_CLOSED_ENUM

#ifdef OS_CLOSED_ENUM
#define XPC_ENUM(_name, _type, ...) \
		OS_CLOSED_ENUM(_name, _type, __VA_ARGS__)
#else // OS_CLOSED_ENUM
#define XPC_ENUM(_name, _type, ...) \
		OS_ENUM(_name, _type, __VA_ARGS__)
#endif // OS_CLOSED_ENUM

#if __has_attribute(swift_name)
# define XPC_SWIFT_NAME(_name) __attribute__((swift_name(_name)))
#else
# define XPC_SWIFT_NAME(_name) // __has_attribute(swift_name)
#endif

#define XPC_SWIFT_UNAVAILABLE(msg) __swift_unavailable(msg)
#define XPC_SWIFT_NOEXPORT XPC_SWIFT_UNAVAILABLE("Unavailable in Swift from the XPC C Module")

__END_DECLS

#endif // __XPC_BASE_H__ 
