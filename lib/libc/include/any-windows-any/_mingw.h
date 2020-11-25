/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _INC__MINGW_H
#define _INC__MINGW_H

#include "_mingw_mac.h"
#include "_mingw_secapi.h"

/* Include _cygwin.h if we're building a Cygwin application. */
#ifdef __CYGWIN__
#include "_cygwin.h"
#endif

/* Target specific macro replacement for type "long".  In the Windows API,
   the type long is always 32 bit, even if the target is 64 bit (LLP64).
   On 64 bit Cygwin, the type long is 64 bit (LP64).  So, to get the right
   sized definitions and declarations, all usage of type long in the Windows
   headers have to be replaced by the below defined macro __LONG32. */
#ifndef __LP64__	/* 32 bit target, 64 bit Mingw target */
#define __LONG32 long
#else			/* 64 bit Cygwin target */
#define __LONG32 int
#endif

/* C/C++ specific language defines.  */
#ifdef _WIN64
#ifdef __stdcall
#undef __stdcall
#endif
#define __stdcall
#endif

#ifndef __GNUC__
# ifndef __MINGW_IMPORT
#  define __MINGW_IMPORT  __declspec(dllimport)
# endif
# ifndef _CRTIMP
#  define _CRTIMP  __declspec(dllimport)
# endif
# define __DECLSPEC_SUPPORTED
# define __attribute__(x) /* nothing */
#else /* __GNUC__ */
# ifdef __declspec
#  ifndef __MINGW_IMPORT
/* Note the extern. This is needed to work around GCC's
limitations in handling dllimport attribute.  */
#   define __MINGW_IMPORT  extern __attribute__ ((__dllimport__))
#  endif
#  ifndef _CRTIMP
#    undef __USE_CRTIMP
#    if !defined (_CRTBLD) && !defined (_SYSCRT)
#      define __USE_CRTIMP 1
#    endif
#    ifdef __USE_CRTIMP
#      define _CRTIMP  __attribute__ ((__dllimport__))
#    else
#      define _CRTIMP
#    endif
#  endif
#  define __DECLSPEC_SUPPORTED
# else /* __declspec */
#  undef __DECLSPEC_SUPPORTED
#  undef __MINGW_IMPORT
#  ifndef _CRTIMP
#   define _CRTIMP
#  endif
# endif /* __declspec */
#endif /* __GNUC__ */

#ifdef _MSC_VER
#define USE___UUIDOF	1
#else
#define USE___UUIDOF	0
#endif

#if !defined(_MSC_VER) && !defined(_inline)
#define _inline __inline
#endif

#ifdef __cplusplus
# define __CRT_INLINE inline
#elif defined(_MSC_VER)
# define __CRT_INLINE __inline
#else
# if ((__MINGW_GNUC_PREREQ(4, 3) || defined(__clang__)) && __STDC_VERSION__ >= 199901L)
#  define __CRT_INLINE extern inline __attribute__((__gnu_inline__))
# else
#  define __CRT_INLINE extern __inline__
# endif
#endif

#if !defined(__MINGW_INTRIN_INLINE) && defined(__GNUC__)
#define __MINGW_INTRIN_INLINE extern __inline__ __attribute__((__always_inline__,__gnu_inline__))
#endif

#ifndef __CYGWIN__
#ifdef __NO_INLINE__
#undef __CRT__NO_INLINE
#define __CRT__NO_INLINE 1
#endif
#endif

#ifdef __cplusplus
# define __UNUSED_PARAM(x)
#else
# ifdef __GNUC__
#  define __UNUSED_PARAM(x) x __attribute__ ((__unused__))
# else
#  define __UNUSED_PARAM(x) x
# endif
#endif

#ifndef __GNUC__
# ifdef _MSC_VER
#  define __restrict__  __restrict
# else
#  define __restrict__	/* nothing */
# endif
#endif /* !__GNUC__ */

#if __MINGW_GNUC_PREREQ (3,1) && !defined __GNUG__
# define __restrict_arr __restrict
#elif defined(_MSC_VER)
# define __restrict_arr __restrict
#else
# ifdef __GNUC__
#  define __restrict_arr        /* Not supported in old GCC.  */
# else
#  if defined __STDC_VERSION__ && __STDC_VERSION__ >= 199901L
#   define __restrict_arr       restrict
#  else
#   define __restrict_arr       /* Not supported.  */
#  endif
# endif
#endif

#ifdef __GNUC__
#define __MINGW_ATTRIB_NORETURN __attribute__ ((__noreturn__))
#define __MINGW_ATTRIB_CONST __attribute__ ((__const__))
#elif __MINGW_MSC_PREREQ(12, 0)
#define __MINGW_ATTRIB_NORETURN __declspec(noreturn)
#define __MINGW_ATTRIB_CONST
#else
#define __MINGW_ATTRIB_NORETURN
#define __MINGW_ATTRIB_CONST
#endif

#if __MINGW_GNUC_PREREQ (3, 0)
#define __MINGW_ATTRIB_MALLOC __attribute__ ((__malloc__))
#define __MINGW_ATTRIB_PURE __attribute__ ((__pure__))
#elif __MINGW_MSC_PREREQ(14, 0)
#define __MINGW_ATTRIB_MALLOC __declspec(noalias) __declspec(restrict)
#define __MINGW_ATTRIB_PURE
#else
#define __MINGW_ATTRIB_MALLOC
#define __MINGW_ATTRIB_PURE
#endif

/* Attribute `nonnull' was valid as of gcc 3.3.  We don't use GCC's
   variadiac macro facility, because variadic macros cause syntax
   errors with  --traditional-cpp.  */
#if  __MINGW_GNUC_PREREQ (3, 3)
#define __MINGW_ATTRIB_NONNULL(arg) __attribute__ ((__nonnull__ (arg)))
#else
#define __MINGW_ATTRIB_NONNULL(arg)
#endif /* GNUC >= 3.3 */

#ifdef __GNUC__
#define __MINGW_ATTRIB_UNUSED __attribute__ ((__unused__))
#else
#define __MINGW_ATTRIB_UNUSED
#endif /* ATTRIBUTE_UNUSED */

#if  __MINGW_GNUC_PREREQ (3, 1)
#define __MINGW_ATTRIB_USED __attribute__ ((__used__))
#define __MINGW_ATTRIB_DEPRECATED __attribute__ ((__deprecated__))
#if __MINGW_GNUC_PREREQ (4, 5) || defined (__clang__)
#define __MINGW_ATTRIB_DEPRECATED_MSG(x) __attribute__ ((__deprecated__(x)))
#endif
#elif __MINGW_MSC_PREREQ(12, 0)
#define __MINGW_ATTRIB_USED
#define __MINGW_ATTRIB_DEPRECATED __declspec(deprecated)
#else
#define __MINGW_ATTRIB_USED __MINGW_ATTRIB_UNUSED
#define __MINGW_ATTRIB_DEPRECATED
#endif /* GNUC >= 3.1 */

#ifndef __MINGW_ATTRIB_DEPRECATED_MSG
#define __MINGW_ATTRIB_DEPRECATED_MSG(x) __MINGW_ATTRIB_DEPRECATED
#endif

#if  __MINGW_GNUC_PREREQ (3, 3)
#define __MINGW_NOTHROW __attribute__ ((__nothrow__))
#elif __MINGW_MSC_PREREQ(12, 0) && defined (__cplusplus)
#define __MINGW_NOTHROW __declspec(nothrow)
#else
#define __MINGW_NOTHROW
#endif

#if __MINGW_GNUC_PREREQ (4, 4)
#define __MINGW_ATTRIB_NO_OPTIMIZE __attribute__((__optimize__ ("0")))
#else
#define __MINGW_ATTRIB_NO_OPTIMIZE
#endif

#if __MINGW_GNUC_PREREQ (4, 4)
#define __MINGW_PRAGMA_PARAM(x) _Pragma (#x)
#elif __MINGW_MSC_PREREQ (13, 1)
#define __MINGW_PRAGMA_PARAM(x) __pragma (x)
#else
#define __MINGW_PRAGMA_PARAM(x)
#endif

#define __MINGW_BROKEN_INTERFACE(x) \
  __MINGW_PRAGMA_PARAM(message ("Interface " _CRT_STRINGIZE(x) \
  " has unverified layout."))

#ifndef __MSVCRT_VERSION__
/*  High byte is the major version, low byte is the minor. */
# ifndef _UCRT
#  define __MSVCRT_VERSION__ 0x700
# else
#  define __MSVCRT_VERSION__ 0xE00
# endif
#endif


#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0603
#endif

#ifndef _INT128_DEFINED
#define _INT128_DEFINED
#ifdef __GNUC__
#define __int8 char
#define __int16 short
#define __int32 int
#define __int64 long long
#ifdef _WIN64
#if (__clang_major__ > 3 || (__clang_major__ == 3 && __clang_minor__ >= 1)) && \
    !defined(__SIZEOF_INT128__) /* clang >= 3.1 has __int128 but no size macro */
#define __SIZEOF_INT128__ 16
#endif
#ifndef __SIZEOF_INT128__
typedef int __int128 __attribute__ ((__mode__ (TI)));
#endif
#endif
#endif /* __GNUC__ */
#endif /* _INT128_DEFINED */

#ifdef __GNUC__
#define __ptr32
#define __ptr64
#ifndef __unaligned
#define __unaligned
#endif
#ifndef __w64
#define __w64
#endif
#ifdef __cplusplus
#define __forceinline inline __attribute__((__always_inline__))
#else
#define __forceinline extern __inline__ __attribute__((__always_inline__,__gnu_inline__))
#endif /* __cplusplus */
#endif /* __GNUC__ */

#if !defined(_WIN32) && !defined(__CYGWIN__)
#error Only Win32 target is supported!
#endif

#ifndef __nothrow
#ifdef __cplusplus
#define __nothrow __MINGW_NOTHROW
#else
#define __nothrow
#endif
#endif /* __nothrow */

#include <vadefs.h>	/* other headers depend on this include */

#ifndef _CRT_STRINGIZE
#define __CRT_STRINGIZE(_Value) #_Value
#define _CRT_STRINGIZE(_Value) __CRT_STRINGIZE(_Value)
#endif /* _CRT_STRINGIZE */

#ifndef _CRT_WIDE
#define __CRT_WIDE(_String) L ## _String
#define _CRT_WIDE(_String) __CRT_WIDE(_String)
#endif /* _CRT_WIDE */

#ifndef _W64
#define _W64
#endif

#ifndef _CRTIMP_NOIA64
#ifdef __ia64__
#define _CRTIMP_NOIA64
#else
#define _CRTIMP_NOIA64 _CRTIMP
#endif
#endif /* _CRTIMP_NOIA64 */

#ifndef _CRTIMP2
#define _CRTIMP2 _CRTIMP
#endif

#ifndef _CRTIMP_ALTERNATIVE
#define _CRTIMP_ALTERNATIVE _CRTIMP
#define _CRT_ALTERNATIVE_IMPORTED
#endif /* _CRTIMP_ALTERNATIVE */

#ifndef _MRTIMP2
#define _MRTIMP2  _CRTIMP
#endif

/* We have to define _DLL for gcc based mingw version. This define is set
   by VC, when DLL-based runtime is used. So, gcc based runtime just have
   DLL-base runtime, therefore this define has to be set.
   As our headers are possibly used by windows compiler having a static
   C-runtime, we make this definition gnu compiler specific here.  */
#if !defined (_DLL) && defined (__GNUC__)
#define _DLL
#endif

#ifndef _MT
#define _MT
#endif

#ifndef _MCRTIMP
#define _MCRTIMP _CRTIMP
#endif

#ifndef _CRTIMP_PURE
#define _CRTIMP_PURE _CRTIMP
#endif

#ifndef _PGLOBAL
#define _PGLOBAL
#endif

#ifndef _AGLOBAL
#define _AGLOBAL
#endif

#define _SECURECRT_FILL_BUFFER_PATTERN 0xFD
#define _CRT_DEPRECATE_TEXT(_Text) __declspec(deprecated)

#ifndef _CRT_INSECURE_DEPRECATE_MEMORY
#define _CRT_INSECURE_DEPRECATE_MEMORY(_Replacement)
#endif

#ifndef _CRT_INSECURE_DEPRECATE_GLOBALS
#define _CRT_INSECURE_DEPRECATE_GLOBALS(_Replacement)
#endif

#ifndef _CRT_MANAGED_HEAP_DEPRECATE
#define _CRT_MANAGED_HEAP_DEPRECATE
#endif

#ifndef _CRT_OBSOLETE
#define _CRT_OBSOLETE(_NewItem)
#endif

#ifndef __WIDL__

#if defined (_WIN32) && !defined (_WIN64) && !defined (__MINGW_USE_VC2005_COMPAT)
#ifndef _USE_32BIT_TIME_T
#define _USE_32BIT_TIME_T
#endif
#endif

#ifndef _CONST_RETURN
#define _CONST_RETURN
#endif

#ifndef UNALIGNED
#if defined(_M_IA64) || defined(_M_AMD64)
#define UNALIGNED __unaligned
#else
#define UNALIGNED
#endif
#endif /* UNALIGNED */

#ifndef _CRT_ALIGN
#ifdef  _MSC_VER
#define _CRT_ALIGN(x) __declspec(align(x))
#else /* __GNUC__ */
#define _CRT_ALIGN(x) __attribute__ ((__aligned__ (x)))
#endif
#endif /* _CRT_ALIGN */

#endif /* __WIDL__ */

#ifndef __CRTDECL
#define __CRTDECL __cdecl
#endif

#define _ARGMAX 100

#ifndef _TRUNCATE
#define _TRUNCATE ((size_t)-1)
#endif

#ifndef _CRT_UNUSED
#define _CRT_UNUSED(x) (void)x
#endif

/* MSVC defines _NATIVE_NULLPTR_SUPPORTED when nullptr is supported. We emulate it here for GCC. */
#if __MINGW_GNUC_PREREQ(4, 6)
#if defined(__GNUC__) && (defined(__GXX_EXPERIMENTAL_CXX0X__) || __cplusplus >= 201103L)
#define _NATIVE_NULLPTR_SUPPORTED
#endif
#endif

/* We are activating __USE_MINGW_ANSI_STDIO for various define indicators.
 * printf ll modifier (unsupported by msvcrt.dll) is required by C99 and C++11 standards. */
#if (defined (_POSIX) || defined (_POSIX_SOURCE) || defined (_POSIX_C_SOURCE) \
     || defined (_ISOC99_SOURCE) \
     || (defined (__STDC_VERSION__) && __STDC_VERSION__ >= 199901L && __MSVCRT_VERSION__ < 0xE00) \
     || (defined (__cplusplus) && __cplusplus >= 201103L && __MSVCRT_VERSION__ < 0xE00) \
     || defined (_XOPEN_SOURCE) || defined (_XOPEN_SOURCE_EXTENDED) \
     || defined (_GNU_SOURCE) \
     || defined (_SVID_SOURCE)) \
    && !defined(__USE_MINGW_ANSI_STDIO)
/* Enable __USE_MINGW_ANSI_STDIO if user did _not_ specify it explicitly... */
#  define __USE_MINGW_ANSI_STDIO			1
#endif

/* We are defining __USE_MINGW_ANSI_STDIO as 0 or 1 */
#if !defined(__USE_MINGW_ANSI_STDIO)
#define __USE_MINGW_ANSI_STDIO 0      /* was not defined so it should be 0 */
#elif (__USE_MINGW_ANSI_STDIO + 0) != 0 || (1 - __USE_MINGW_ANSI_STDIO - 1) == 2
#define __USE_MINGW_ANSI_STDIO 1      /* was defined as nonzero or empty so it should be 1 */
#else
#define __USE_MINGW_ANSI_STDIO 0      /* was defined as (int)zero and non-empty so it should be 0 */
#endif

/* _dowildcard is an int that controls the globbing of the command line.
 * The MinGW32 (mingw.org) runtime calls it _CRT_glob, so we are adding
 * a compatibility definition here:  you can use either of _CRT_glob or
 * _dowildcard .
 * If _dowildcard is non-zero, the command line will be globbed:  *.*
 * will be expanded to be all files in the startup directory.
 * In the mingw-w64 library a _dowildcard variable is defined as being
 * 0, therefore command line globbing is DISABLED by default. To turn it
 * on and to leave wildcard command line processing MS's globbing code,
 * include a line in one of your source modules defining _dowildcard and
 * setting it to -1, like so:
 * int _dowildcard = -1;
 */
#undef  _CRT_glob
#define _CRT_glob _dowildcard


#if defined(_MSC_VER) && !defined(_MSC_EXTENSIONS)
#define NONAMELESSUNION		1
#endif
#if defined(NONAMELESSSTRUCT) && \
   !defined(NONAMELESSUNION)
#define NONAMELESSUNION		1
#endif
#if defined(NONAMELESSUNION)  && \
   !defined(NONAMELESSSTRUCT)
#define NONAMELESSSTRUCT	1
#endif

#ifndef __ANONYMOUS_DEFINED
#define __ANONYMOUS_DEFINED
#define _ANONYMOUS_UNION  __MINGW_EXTENSION
#define _ANONYMOUS_STRUCT __MINGW_EXTENSION
#ifndef NONAMELESSUNION
#define _UNION_NAME(x)
#define _STRUCT_NAME(x)
#else /* NONAMELESSUNION */
#define _UNION_NAME(x)  x
#define _STRUCT_NAME(x) x
#endif
#endif	/* __ANONYMOUS_DEFINED */

#ifndef DUMMYUNIONNAME
# ifdef NONAMELESSUNION
#  define DUMMYUNIONNAME  u
#  define DUMMYUNIONNAME1 u1	/* Wine uses this variant */
#  define DUMMYUNIONNAME2 u2
#  define DUMMYUNIONNAME3 u3
#  define DUMMYUNIONNAME4 u4
#  define DUMMYUNIONNAME5 u5
#  define DUMMYUNIONNAME6 u6
#  define DUMMYUNIONNAME7 u7
#  define DUMMYUNIONNAME8 u8
#  define DUMMYUNIONNAME9 u9
# else /* NONAMELESSUNION */
#  define DUMMYUNIONNAME
#  define DUMMYUNIONNAME1	/* Wine uses this variant */
#  define DUMMYUNIONNAME2
#  define DUMMYUNIONNAME3
#  define DUMMYUNIONNAME4
#  define DUMMYUNIONNAME5
#  define DUMMYUNIONNAME6
#  define DUMMYUNIONNAME7
#  define DUMMYUNIONNAME8
#  define DUMMYUNIONNAME9
# endif
#endif	/* DUMMYUNIONNAME */

#ifndef DUMMYSTRUCTNAME
# ifdef NONAMELESSUNION
#  define DUMMYSTRUCTNAME  s
#  define DUMMYSTRUCTNAME1 s1	/* Wine uses this variant */
#  define DUMMYSTRUCTNAME2 s2
#  define DUMMYSTRUCTNAME3 s3
#  define DUMMYSTRUCTNAME4 s4
#  define DUMMYSTRUCTNAME5 s5
# else
#  define DUMMYSTRUCTNAME
#  define DUMMYSTRUCTNAME1	/* Wine uses this variant */
#  define DUMMYSTRUCTNAME2
#  define DUMMYSTRUCTNAME3
#  define DUMMYSTRUCTNAME4
#  define DUMMYSTRUCTNAME5
# endif
#endif /* DUMMYSTRUCTNAME */


/* Macros for __uuidof template-based emulation */
#if defined(__cplusplus) && (USE___UUIDOF == 0)

#if __cpp_constexpr >= 200704l && __cpp_inline_variables >= 201606L
#define __CRT_UUID_DECL(type,l,w1,w2,b1,b2,b3,b4,b5,b6,b7,b8)    \
    extern "C++" {                                               \
    template<> struct __mingw_uuidof_s<type> {                   \
        static constexpr IID __uuid_inst = {                     \
            l,w1,w2, {b1,b2,b3,b4,b5,b6,b7,b8}                   \
        };                                                       \
    };                                                           \
    template<> constexpr const GUID &__mingw_uuidof<type>() {    \
        return __mingw_uuidof_s<type>::__uuid_inst;              \
    }                                                            \
    template<> constexpr const GUID &__mingw_uuidof<type*>() {   \
        return  __mingw_uuidof_s<type>::__uuid_inst;             \
    }                                                            \
    }
#else
#define __CRT_UUID_DECL(type,l,w1,w2,b1,b2,b3,b4,b5,b6,b7,b8)           \
    extern "C++" {                                                      \
    template<> inline const GUID &__mingw_uuidof<type>() {              \
        static const IID __uuid_inst = {l,w1,w2, {b1,b2,b3,b4,b5,b6,b7,b8}}; \
        return __uuid_inst;                                             \
    }                                                                   \
    template<> inline const GUID &__mingw_uuidof<type*>() {             \
        return __mingw_uuidof<type>();                                  \
    }                                                                   \
    }
#endif

#define __uuidof(type) __mingw_uuidof<__typeof(type)>()

#else

#define __CRT_UUID_DECL(type,l,w1,w2,b1,b2,b3,b4,b5,b6,b7,b8)

#endif

#ifdef __cplusplus
extern "C" {
#endif


#ifdef __MINGW_INTRIN_INLINE
#ifdef __has_builtin
#define __MINGW_DEBUGBREAK_IMPL !__has_builtin(__debugbreak)
#else
#define __MINGW_DEBUGBREAK_IMPL 1
#endif
#if __MINGW_DEBUGBREAK_IMPL == 1
void __cdecl __debugbreak(void);
__MINGW_INTRIN_INLINE void __cdecl __debugbreak(void)
{
  __asm__ __volatile__("int {$}3":);
}
#endif
#endif

/* mingw-w64 specific functions: */
const char *__mingw_get_crt_info (void);

#ifdef __cplusplus
}
#endif

#endif /* _INC__MINGW_H */

#ifndef MINGW_SDK_INIT
#define MINGW_SDK_INIT

/* for backward compatibility */
#ifndef MINGW_HAS_SECURE_API
#define MINGW_HAS_SECURE_API 1
#endif

#define __STDC_SECURE_LIB__ 200411L
#define __GOT_SECURE_LIB__ __STDC_SECURE_LIB__

#ifndef __WIDL__
#include "sdks/_mingw_ddk.h"
#endif

#endif /* MINGW_SDK_INIT */
