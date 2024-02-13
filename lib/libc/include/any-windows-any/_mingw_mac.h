/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _INC_CRTDEFS_MACRO
#define _INC_CRTDEFS_MACRO

#define __STRINGIFY(x) #x
#define __MINGW64_STRINGIFY(x) \
  __STRINGIFY(x)

#define __MINGW64_VERSION_MAJOR 12
#define __MINGW64_VERSION_MINOR 0
#define __MINGW64_VERSION_BUGFIX 0

/* This macro holds an monotonic increasing value, which indicates
   a specific fix/patch is present on trunk.  This value isn't related to
   minor/major version-macros.  It is increased on demand, if a big
   fix was applied to trunk.  This macro gets just increased on trunk.  For
   other branches its value won't be modified.  */

#define __MINGW64_VERSION_RC 0

#define __MINGW64_VERSION_STR	\
  __MINGW64_STRINGIFY(__MINGW64_VERSION_MAJOR) \
  "." \
  __MINGW64_STRINGIFY(__MINGW64_VERSION_MINOR) \
  "." \
  __MINGW64_STRINGIFY(__MINGW64_VERSION_BUGFIX)

#define __MINGW64_VERSION_STATE "alpha"

/* mingw.org's version macros: these make gcc to define
   MINGW32_SUPPORTS_MT_EH and to use the _CRT_MT global
   and the __mingwthr_key_dtor() function from the MinGW
   CRT in its private gthr-win32.h header. */
#define __MINGW32_MAJOR_VERSION 3
#define __MINGW32_MINOR_VERSION 11

/* Set VC specific compiler target macros.  */
#if defined(__x86_64) && defined(_X86_)
#  undef _X86_  /* _X86_ is not for __x86_64 */
#endif

#if defined(_X86_) && !defined(_M_IX86) && !defined(_M_IA64) \
   && !defined(_M_AMD64) && !defined(__x86_64)
#  if defined(__i486__)
#    define _M_IX86 400
#  elif defined(__i586__)
#    define _M_IX86 500
#  elif defined(__i686__)
#    define _M_IX86 600
#  else
#    define _M_IX86 300
#  endif
#endif /* if defined(_X86_) && !defined(_M_IX86) && !defined(_M_IA64) ... */

#if defined(__x86_64) && !defined(_M_IX86) && !defined(_M_IA64) \
   && !defined(_M_AMD64)
#  define _M_AMD64 100
#  define _M_X64 100
#endif

#if defined(__ia64__) && !defined(_M_IX86) && !defined(_M_IA64) \
   && !defined(_M_AMD64) && !defined(_X86_) && !defined(__x86_64)
#  define _M_IA64 100
#endif

#if defined(__arm__) && !defined(_M_ARM) && !defined(_M_ARMT) \
   && !defined(_M_THUMB)
#  define _M_ARM 100
#  define _M_ARMT 100
#  define _M_THUMB 100
#  ifndef _ARM_
#    define _ARM_ 1
#  endif
#  ifndef _M_ARM_NT
#    define _M_ARM_NT 1
#  endif
#endif

#if defined(__aarch64__) && !defined(_M_ARM64)
#  define _M_ARM64 1
#  ifndef _ARM64_
#    define _ARM64_ 1
#  endif
#endif

#ifndef _X86_
   /* MS does not prefix symbols by underscores for 64-bit.  */
#  ifndef __MINGW_USE_UNDERSCORE_PREFIX
     /* As we have to support older gcc version, which are using underscores
      as symbol prefix for x64, we have to check here for the user label
      prefix defined by gcc. */
#    ifdef __USER_LABEL_PREFIX__
#      pragma push_macro ("_")
#      undef _
#      define _ 1
#      if (__USER_LABEL_PREFIX__ + 0) != 0
#        define __MINGW_USE_UNDERSCORE_PREFIX 1
#      else
#        define __MINGW_USE_UNDERSCORE_PREFIX 0
#      endif
#      undef _
#      pragma pop_macro ("_")
#    else /* ! __USER_LABEL_PREFIX__ */
#      define __MINGW_USE_UNDERSCORE_PREFIX 0
#    endif /* __USER_LABEL_PREFIX__ */
#  endif
#else /* ! ifndef _X86_ */
   /* For x86 we have always to prefix by underscore.  */
#  undef __MINGW_USE_UNDERSCORE_PREFIX
#  define __MINGW_USE_UNDERSCORE_PREFIX 1
#endif /* ifndef _X86_ */

#if __MINGW_USE_UNDERSCORE_PREFIX == 0
#  define __MINGW_IMP_SYMBOL(sym) __imp_##sym
#  define __MINGW_IMP_LSYMBOL(sym) __imp_##sym
#  define __MINGW_USYMBOL(sym) sym
#  define __MINGW_LSYMBOL(sym) _##sym
#else /* ! if __MINGW_USE_UNDERSCORE_PREFIX == 0 */
#  define __MINGW_IMP_SYMBOL(sym) _imp__##sym
#  define __MINGW_IMP_LSYMBOL(sym) __imp__##sym
#  define __MINGW_USYMBOL(sym) _##sym
#  define __MINGW_LSYMBOL(sym) sym
#endif /* if __MINGW_USE_UNDERSCORE_PREFIX == 0 */

#define __MINGW_ASM_CALL(func) __asm__(__MINGW64_STRINGIFY(__MINGW_USYMBOL(func)))
#define __MINGW_ASM_CRT_CALL(func) __asm__(__STRINGIFY(func))

#ifndef __PTRDIFF_TYPE__
#  ifdef _WIN64
#    define __PTRDIFF_TYPE__ long long int
#  else
#    define __PTRDIFF_TYPE__ long int
#  endif
#endif

#ifndef __SIZE_TYPE__
#  ifdef _WIN64
#    define __SIZE_TYPE__ long long unsigned int
#  else
#    define __SIZE_TYPE__ long unsigned int
#  endif
#endif

#ifndef __WCHAR_TYPE__
#  define __WCHAR_TYPE__ unsigned short
#endif

#ifndef __WINT_TYPE__
#  define __WINT_TYPE__ unsigned short
#endif

#undef __MINGW_EXTENSION

#ifdef __WIDL__
#  define __MINGW_EXTENSION
#else
#  if defined(__GNUC__) || defined(__GNUG__)
#    define __MINGW_EXTENSION __extension__
#  else
#    define __MINGW_EXTENSION
#  endif
#endif /* __WIDL__ */

/* Special case nameless struct/union.  */
#ifndef __C89_NAMELESS
#  define __C89_NAMELESS __MINGW_EXTENSION
#  define __C89_NAMELESSSTRUCTNAME
#  define __C89_NAMELESSSTRUCTNAME1
#  define __C89_NAMELESSSTRUCTNAME2
#  define __C89_NAMELESSSTRUCTNAME3
#  define __C89_NAMELESSSTRUCTNAME4
#  define __C89_NAMELESSSTRUCTNAME5
#  define __C89_NAMELESSUNIONNAME
#  define __C89_NAMELESSUNIONNAME1
#  define __C89_NAMELESSUNIONNAME2
#  define __C89_NAMELESSUNIONNAME3
#  define __C89_NAMELESSUNIONNAME4
#  define __C89_NAMELESSUNIONNAME5
#  define __C89_NAMELESSUNIONNAME6
#  define __C89_NAMELESSUNIONNAME7
#  define __C89_NAMELESSUNIONNAME8
#endif

#ifndef __GNU_EXTENSION
#  define __GNU_EXTENSION __MINGW_EXTENSION
#endif

/* MinGW-w64 has some additional C99 printf/scanf feature support.
   So we add some helper macros to ease recognition of them.  */
#define __MINGW_HAVE_ANSI_C99_PRINTF 1
#define __MINGW_HAVE_WIDE_C99_PRINTF 1
#define __MINGW_HAVE_ANSI_C99_SCANF 1
#define __MINGW_HAVE_WIDE_C99_SCANF 1

#ifdef __MINGW_USE_BROKEN_INTERFACE
#  define __MINGW_POISON_NAME(__IFACE) __IFACE
#else
#  define __MINGW_POISON_NAME(__IFACE) \
     __IFACE##_layout_has_not_been_verified_and_its_declaration_is_most_likely_incorrect
#endif

#ifndef __MSABI_LONG
#  ifndef __LP64__
#    define __MSABI_LONG(x) x ## l
#  else
#    define __MSABI_LONG(x) x
#  endif
#endif

#if __GNUC__
#  define __MINGW_GCC_VERSION	(__GNUC__ * 10000 + \
      __GNUC_MINOR__	* 100	+ \
      __GNUC_PATCHLEVEL__)
#else
#  define __MINGW_GCC_VERSION 0
#endif

#if defined (__GNUC__) && defined (__GNUC_MINOR__)
#  define __MINGW_GNUC_PREREQ(major, minor) \
      (__GNUC__ > (major) \
      || (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#else
#  define __MINGW_GNUC_PREREQ(major, minor) 0
#endif

#if defined (_MSC_VER)
#  define __MINGW_MSC_PREREQ(major, minor) \
      (_MSC_VER >= (major * 100 + minor * 10))
#else
#  define __MINGW_MSC_PREREQ(major, minor) 0
#endif

#ifdef __MINGW_MSVC_COMPAT_WARNINGS
#  if __MINGW_GNUC_PREREQ (4, 5)
#    define __MINGW_ATTRIB_DEPRECATED_STR(X) \
       __attribute__ ((__deprecated__ (X)))
#  else
#    define __MINGW_ATTRIB_DEPRECATED_STR(X) \
       __MINGW_ATTRIB_DEPRECATED
#  endif
#else
#  define __MINGW_ATTRIB_DEPRECATED_STR(X)
#endif /* ifdef __MINGW_MSVC_COMPAT_WARNINGS */

#define __MINGW_SEC_WARN_STR \
  "This function or variable may be unsafe, use _CRT_SECURE_NO_WARNINGS to disable deprecation"

#define __MINGW_MSVC2005_DEPREC_STR \
  "This POSIX function is deprecated beginning in Visual C++ 2005, use _CRT_NONSTDC_NO_DEPRECATE to disable deprecation"

#if !defined (_CRT_NONSTDC_NO_DEPRECATE)
#  define __MINGW_ATTRIB_DEPRECATED_MSVC2005 \
      __MINGW_ATTRIB_DEPRECATED_STR(__MINGW_MSVC2005_DEPREC_STR)
#else
#  define __MINGW_ATTRIB_DEPRECATED_MSVC2005
#endif

#if !defined (_CRT_SECURE_NO_WARNINGS) || (_CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES == 0)
#  define __MINGW_ATTRIB_DEPRECATED_SEC_WARN \
      __MINGW_ATTRIB_DEPRECATED_STR(__MINGW_SEC_WARN_STR)
#else
#  define __MINGW_ATTRIB_DEPRECATED_SEC_WARN
#endif

#define __MINGW_MS_PRINTF(__format,__args) \
  __attribute__((__format__(ms_printf, __format,__args)))

#define __MINGW_MS_SCANF(__format,__args) \
  __attribute__((__format__(ms_scanf,  __format,__args)))

#define __MINGW_GNU_PRINTF(__format,__args) \
  __attribute__((__format__(gnu_printf,__format,__args)))

#define __MINGW_GNU_SCANF(__format,__args) \
  __attribute__((__format__(gnu_scanf, __format,__args)))

#undef __mingw_ovr
#undef __mingw_static_ovr

#ifdef __cplusplus
#  define __mingw_ovr  inline __cdecl
#  define __mingw_static_ovr static __mingw_ovr
#elif defined (__GNUC__)
#  define __mingw_ovr static \
      __attribute__ ((__unused__)) __inline__ __cdecl
#  define __mingw_static_ovr __mingw_ovr
#else
#  define __mingw_ovr static __cdecl
#  define __mingw_static_ovr __mingw_ovr
#endif /* __cplusplus */

#if __MINGW_GNUC_PREREQ(4, 3) || defined(__clang__)
#  define __mingw_attribute_artificial \
     __attribute__((__artificial__))
#else
#  define __mingw_attribute_artificial
#endif

#define __MINGW_SELECTANY  __attribute__((__selectany__))

#pragma push_macro("__has_builtin")
#ifndef __has_builtin
#  define __has_builtin(x) 0
#endif

#if _FORTIFY_SOURCE > 0 && __OPTIMIZE__ > 0 && __MINGW_GNUC_PREREQ(4, 1)
#  if _FORTIFY_SOURCE > 3
#    warning Using _FORTIFY_SOURCE=3 (levels > 3 are not supported)
#  endif
#  if _FORTIFY_SOURCE > 2
#    if __has_builtin(__builtin_dynamic_object_size)
#      define __MINGW_FORTIFY_LEVEL 3
#    else
#      warning Using _FORTIFY_SOURCE=2 (level 3 requires __builtin_dynamic_object_size support)
#      define __MINGW_FORTIFY_LEVEL 2
#    endif
#  elif _FORTIFY_SOURCE > 1
#    define __MINGW_FORTIFY_LEVEL 2
#  else
#    define __MINGW_FORTIFY_LEVEL 1
#  endif
#else
#  define __MINGW_FORTIFY_LEVEL 0
#endif

#if __MINGW_FORTIFY_LEVEL > 0
   /* Calling an function with __attribute__((__warning__("...")))
      from a system include __inline__ function does not print
      a warning unless caller has __attribute__((__artificial__)). */
#  define __mingw_bos_declare \
     void __cdecl __chk_fail(void) __attribute__((__noreturn__)); \
     void __cdecl __mingw_chk_fail_warn(void) __MINGW_ASM_CALL(__chk_fail) \
     __attribute__((__noreturn__)) \
     __attribute__((__warning__("Buffer overflow detected")))
#  if __MINGW_FORTIFY_LEVEL > 2
#    define __mingw_bos(p, maxtype) \
       __builtin_dynamic_object_size((p), (maxtype) > 0)
#    define __mingw_bos_known(p) \
       (__builtin_object_size(p, 0) != (size_t)-1 \
       || !__builtin_constant_p(__mingw_bos(p, 0)))
#  else
#    define __mingw_bos(p, maxtype) \
       __builtin_object_size((p), ((maxtype) > 0) && (__MINGW_FORTIFY_LEVEL > 1))
#    define __mingw_bos_known(p) \
       (__mingw_bos(p, 0) != (size_t)-1)
#  endif
#  define __mingw_bos_cond_chk(c) \
     (__builtin_expect((c), 1) ? (void)0 : __chk_fail())
#  define __mingw_bos_ptr_chk(p, n, maxtype) \
     __mingw_bos_cond_chk(!__mingw_bos_known(p) || __mingw_bos(p, maxtype) >= (size_t)(n))
#  define __mingw_bos_ptr_chk_warn(p, n, maxtype) \
     ((__mingw_bos_known(p) \
     && __builtin_constant_p(__mingw_bos(p, maxtype) < (size_t)(n)) \
     && __mingw_bos(p, maxtype) < (size_t)(n)) \
     ? __mingw_chk_fail_warn() : __mingw_bos_ptr_chk(p, n, maxtype))
#  define __mingw_bos_ovr __mingw_ovr \
     __attribute__((__always_inline__)) \
     __mingw_attribute_artificial
#  define __mingw_bos_extern_ovr extern __inline__ __cdecl \
     __attribute__((__always_inline__, __gnu_inline__)) \
     __mingw_attribute_artificial
#else
#  define __mingw_bos_ovr __mingw_ovr
#endif /* __MINGW_FORTIFY_LEVEL > 0 */

/* If _FORTIFY_SOURCE is enabled, some inline functions may use
   __builtin_va_arg_pack().  GCC may report an error if the address
   of such a function is used.  Set _FORTIFY_VA_ARG=0 in this case.
   Clang doesn't, as of version 15, yet implement __builtin_va_arg_pack().  */
#if __MINGW_FORTIFY_LEVEL > 0 \
    && ((__MINGW_GNUC_PREREQ(4, 3) && !defined(__clang__)) \
    || __has_builtin(__builtin_va_arg_pack)) \
    && (!defined(_FORTIFY_VA_ARG) || _FORTIFY_VA_ARG > 0)
#  define __MINGW_FORTIFY_VA_ARG 1
#else
#  define __MINGW_FORTIFY_VA_ARG 0
#endif

#pragma pop_macro("__has_builtin")

/* Enable workaround for ABI incompatibility on affected platforms */
#ifndef WIDL_EXPLICIT_AGGREGATE_RETURNS
#if defined(__GNUC__) && defined(__cplusplus)
#define  WIDL_EXPLICIT_AGGREGATE_RETURNS
#endif
#endif

#endif	/* _INC_CRTDEFS_MACRO */
