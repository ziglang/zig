/*! @header
 *  This header defines macros used in the implementation of <simd/simd.h>
 *  types and functions. Even though they are exposed in a public header,
 *  the macros defined in this header are implementation details, and you
 *  should not use or rely on them. They may be changed or removed entirely
 *  in a future release.
 *
 *  @copyright 2016-2017 Apple, Inc. All rights reserved.
 *  @unsorted                                                                 */

#ifndef SIMD_BASE
#define SIMD_BASE

/*  Define __has_attribute and __has_include if they aren't available         */
# ifndef __has_attribute
#  define __has_attribute(__x) 0
# endif
# ifndef __has_include
#  define __has_include(__x) 0
# endif
# ifndef __has_feature
#  define __has_feature(__x) 0
# endif

# if __has_attribute(__ext_vector_type__) && __has_attribute(__overloadable__)
#  define SIMD_COMPILER_HAS_REQUIRED_FEATURES 1
# else
/*  Your compiler is missing one or more features that are hard requirements
 *  for any <simd/simd.h> support. None of the types or functions defined by
 *  the simd headers will be available.                                       */
#  define SIMD_COMPILER_HAS_REQUIRED_FEATURES 0
# endif

# if SIMD_COMPILER_HAS_REQUIRED_FEATURES
#  if __has_include(<TargetConditionals.h>) && __has_include(<Availability.h>)
#   include <TargetConditionals.h>
#   include <Availability.h>
/*  A number of new features are added in newer releases; most of these are
 *  inline in the header, which makes them available even when targeting older
 *  OS versions. Those that make external calls, however, are only available
 *  when targeting the release in which they became available. Because of the
 *  way in which simd functions are overloaded, the usual weak-linking tricks
 *  do not work; these functions are simply unavailable when targeting older
 *  versions of the library.                                                  */
#   if TARGET_OS_RTKIT
#    define SIMD_LIBRARY_VERSION 5
#   elif __MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_13_0   || \
        __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_16_0 || \
        __WATCH_OS_VERSION_MIN_REQUIRED  >= __WATCHOS_9_0 || \
        __TV_OS_VERSION_MIN_REQUIRED     >= __TVOS_16_0   || \
        __BRIDGE_OS_VERSION_MIN_REQUIRED >= 70000   || \
        __DRIVERKIT_VERSION_MIN_REQUIRED >= __DRIVERKIT_22_0
#    define SIMD_LIBRARY_VERSION 5
#   elif   __MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_12_0   || \
        __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_15_0 || \
         __WATCH_OS_VERSION_MIN_REQUIRED >= __WATCHOS_8_0 || \
            __TV_OS_VERSION_MIN_REQUIRED >= __TVOS_15_0   || \
        __BRIDGE_OS_VERSION_MIN_REQUIRED >= 60000   || \
        __DRIVERKIT_VERSION_MIN_REQUIRED >= __DRIVERKIT_21_0
#    define SIMD_LIBRARY_VERSION 4
#   elif __MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_10_13   || \
        __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_11_0 || \
         __WATCH_OS_VERSION_MIN_REQUIRED >= __WATCHOS_4_0 || \
            __TV_OS_VERSION_MIN_REQUIRED >= __TVOS_11_0   || \
        __DRIVERKIT_VERSION_MIN_REQUIRED >= __DRIVERKIT_19_0
#    define SIMD_LIBRARY_VERSION 3
#   elif __MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_10_12   || \
        __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_10_0 || \
         __WATCH_OS_VERSION_MIN_REQUIRED >= __WATCHOS_3_0 || \
            __TV_OS_VERSION_MIN_REQUIRED >= __TVOS_10_0
#    define SIMD_LIBRARY_VERSION 2
#   elif __MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_10_10   || \
        __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_8_0
#    define SIMD_LIBRARY_VERSION 1
#   else
#    define SIMD_LIBRARY_VERSION 0
#   endif
#  else /* !__has_include(<TargetContidionals.h>) && __has_include(<Availability.h>) */
#   define SIMD_LIBRARY_VERSION 5
#   define __API_AVAILABLE(...) /* Nothing */
#  endif

/*  The simd types interoperate with the native simd intrinsic types for each
 *  architecture; the headers that define those types and operations are
 *  automatically included with simd.h                                        */
#  if defined __ARM_NEON__
#   include <arm_neon.h>
#  elif defined __i386__ || defined __x86_64__
#   include <immintrin.h>
#  endif

/*  Define a number of function attributes used by the simd functions.        */
#  if __has_attribute(__always_inline__)
#   define SIMD_INLINE  __attribute__((__always_inline__))
#  else
#   define SIMD_INLINE  inline
#  endif

#  if __has_attribute(__const__)
#   define SIMD_CONST   __attribute__((__const__))
#  else
#   define SIMD_CONST   /* nothing */
#  endif

#  if __has_attribute(__nodebug__)
#   define SIMD_NODEBUG __attribute__((__nodebug__))
#  else
#   define SIMD_NODEBUG /* nothing */
#  endif

#  if __has_attribute(__deprecated__)
#   define SIMD_DEPRECATED(message) __attribute__((__deprecated__(message)))
#  else
#   define SIMD_DEPRECATED(message) /* nothing */
#  endif

#define SIMD_OVERLOAD __attribute__((__overloadable__))
#define SIMD_CPPFUNC  SIMD_INLINE SIMD_CONST SIMD_NODEBUG
#define SIMD_CFUNC    SIMD_CPPFUNC SIMD_OVERLOAD
#define SIMD_NOINLINE SIMD_CONST SIMD_NODEBUG SIMD_OVERLOAD
#define SIMD_NONCONST SIMD_INLINE SIMD_NODEBUG SIMD_OVERLOAD
#define __SIMD_INLINE__     SIMD_CPPFUNC
#define __SIMD_ATTRIBUTES__ SIMD_CFUNC
#define __SIMD_OVERLOAD__   SIMD_OVERLOAD

#  if __has_feature(cxx_constexpr)
#   define SIMD_CONSTEXPR constexpr
#  else
#   define SIMD_CONSTEXPR /* nothing */
#  endif

#  if __has_feature(cxx_noexcept)
#   define SIMD_NOEXCEPT noexcept
#  else
#   define SIMD_NOEXCEPT /* nothing */
#  endif

#if defined __cplusplus
/*! @abstract A boolean scalar.                                               */
typedef  bool simd_bool;
#else
/*! @abstract A boolean scalar.                                               */
typedef _Bool simd_bool;
#endif
/*! @abstract A boolean scalar.
 *  @discussion This type is deprecated; In C or Objective-C sources, use
 *  `_Bool` instead. In C++ sources, use `bool`.                              */
typedef simd_bool __SIMD_BOOLEAN_TYPE__;

# endif /* SIMD_COMPILER_HAS_REQUIRED_FEATURES */
#endif /* defined SIMD_BASE */
