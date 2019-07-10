/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _INC_CRTDEFS
#define _INC_CRTDEFS

#include <_mingw.h>

#ifndef __WIDL__
#undef _CRT_PACKING
#define _CRT_PACKING 8
#pragma pack(push,_CRT_PACKING)
#endif

#ifdef __ERRCODE_DEFINED_MS
/* #define __ERRCODE_DEFINED_MS */
typedef int errcode;
#endif

#ifndef _CRTNOALIAS
#define _CRTNOALIAS
#endif

#ifndef _CRTRESTRICT
#define _CRTRESTRICT
#endif

#ifndef _SIZE_T_DEFINED
#define _SIZE_T_DEFINED
#undef size_t
#ifdef _WIN64
__MINGW_EXTENSION typedef unsigned __int64 size_t;
#else
typedef unsigned int size_t;
#endif /* _WIN64 */
#endif /* _SIZE_T_DEFINED */

#ifndef _SSIZE_T_DEFINED
#define _SSIZE_T_DEFINED
#undef ssize_t
#ifdef _WIN64
__MINGW_EXTENSION typedef __int64 ssize_t;
#else
typedef int ssize_t;
#endif /* _WIN64 */
#endif /* _SSIZE_T_DEFINED */

#ifndef _RSIZE_T_DEFINED
typedef size_t rsize_t;
#define _RSIZE_T_DEFINED
#endif

#ifndef _INTPTR_T_DEFINED
#define _INTPTR_T_DEFINED
#ifndef __intptr_t_defined
#define __intptr_t_defined
#undef intptr_t
#ifdef _WIN64
__MINGW_EXTENSION typedef __int64 intptr_t;
#else
typedef int intptr_t;
#endif /* _WIN64 */
#endif /* __intptr_t_defined */
#endif /* _INTPTR_T_DEFINED */

#ifndef _UINTPTR_T_DEFINED
#define _UINTPTR_T_DEFINED
#ifndef __uintptr_t_defined
#define __uintptr_t_defined
#undef uintptr_t
#ifdef _WIN64
__MINGW_EXTENSION typedef unsigned __int64 uintptr_t;
#else
typedef unsigned int uintptr_t;
#endif /* _WIN64 */
#endif /* __uintptr_t_defined */
#endif /* _UINTPTR_T_DEFINED */

#ifndef _PTRDIFF_T_DEFINED
#define _PTRDIFF_T_DEFINED
#ifndef _PTRDIFF_T_
#define _PTRDIFF_T_
#undef ptrdiff_t
#ifdef _WIN64
__MINGW_EXTENSION typedef __int64 ptrdiff_t;
#else
typedef int ptrdiff_t;
#endif /* _WIN64 */
#endif /* _PTRDIFF_T_ */
#endif /* _PTRDIFF_T_DEFINED */

#ifndef _WCHAR_T_DEFINED
#define _WCHAR_T_DEFINED
#if !defined(__cplusplus) && !defined(__WIDL__)
typedef unsigned short wchar_t;
#endif /* C++ */
#endif /* _WCHAR_T_DEFINED */

#ifndef _WCTYPE_T_DEFINED
#define _WCTYPE_T_DEFINED
#ifndef _WINT_T
#define _WINT_T
typedef unsigned short wint_t;
typedef unsigned short wctype_t;
#endif /* _WINT_T */
#endif /* _WCTYPE_T_DEFINED */

#ifndef _ERRCODE_DEFINED
#define _ERRCODE_DEFINED
typedef int errno_t;
#endif

#ifndef _TIME32_T_DEFINED
#define _TIME32_T_DEFINED
typedef long __time32_t;
#endif

#ifndef _TIME64_T_DEFINED
#define _TIME64_T_DEFINED
__MINGW_EXTENSION typedef __int64 __time64_t;
#endif /* _TIME64_T_DEFINED */

#ifdef _USE_32BIT_TIME_T
#ifdef _WIN64
#error You cannot use 32-bit time_t (_USE_32BIT_TIME_T) with _WIN64
#undef _USE_32BIT_TIME_T
#endif
#endif /* _USE_32BIT_TIME_T */

#ifndef _TIME_T_DEFINED
#define _TIME_T_DEFINED
#ifdef _USE_32BIT_TIME_T
typedef __time32_t time_t;
#else
typedef __time64_t time_t;
#endif
#endif /* _TIME_T_DEFINED */

#ifndef _CRT_SECURE_CPP_NOTHROW
#define _CRT_SECURE_CPP_NOTHROW throw()
#endif

#if defined(__cplusplus) && _CRT_SECURE_CPP_OVERLOAD_SECURE_NAMES

#define __DEFINE_CPP_OVERLOAD_SECURE_FUNC_0_0(__ret,__func,__dsttype,__dst) \
  extern "C++" { \
    template <size_t __size> \
    inline __ret __cdecl __func(__dsttype (&__dst)[__size]) { \
        return __func(__dst,__size); \
    } \
  }

#define __DEFINE_CPP_OVERLOAD_SECURE_FUNC_0_1(__ret,__func,__dsttype,__dst,__type1,__arg1) \
  extern "C++" {\
    template <size_t __size> \
    inline __ret __cdecl __func(__dsttype (&__dst)[__size], __type1 __arg1) { \
        return __func(__dst,__size,__arg1);  \
    }\
  }

#define __DEFINE_CPP_OVERLOAD_SECURE_FUNC_0_2(__ret,__func,__dsttype,__dst,__type1,__arg1,__type2,__arg2)\
  extern "C++" {\
    template <size_t __size> inline\
    __ret __cdecl __func(__dsttype (&__dst)[__size], __type1 __arg1, __type2 __arg2) { \
        return __func(__dst,__size,__arg1,__arg2);  \
    }\
  }

#define __DEFINE_CPP_OVERLOAD_SECURE_FUNC_0_3(__ret,__func,__dsttype,__dst,__type1,__arg1,__type2,__arg2,__type3,__arg3) \
  extern "C++" { \
    template <size_t __size> inline \
    __ret __cdecl __func(__dsttype (&__dst)[__size], __type1 __arg1, __type2 __arg2, __type3 __arg3) { \
        return __func(__dst,__size,__arg1,__arg2,__arg3); \
    }\
  }

#define __DEFINE_CPP_OVERLOAD_SECURE_FUNC_0_4(__ret,__func,__dsttype,__dst,__type1,__arg1,__type2,__arg2,__type3,__arg3,__type4,__arg4) \
  extern "C++" { \
    template <size_t __size> inline \
    __ret __cdecl __func(__dsttype (&__dst)[__size], __type1 __arg1, __type2 __arg2, __type3 __arg3, __type4 __arg4) { \
        return __func(__dst,__size,__arg1,__arg2,__arg3,__arg4); \
    }\
  }

#define __DEFINE_CPP_OVERLOAD_SECURE_FUNC_1_1(__ret,__func,__type0,__arg0,__dsttype,__dst,__type1,__arg1) \
  extern "C++" { \
    template <size_t __size> inline \
      __ret __cdecl __func(__type0 __arg0, __dsttype (&__dst)[__size], __type1 __arg1) { \
      return __func(__arg0, __dst, __size, __arg1); \
    } \
  }

#define __DEFINE_CPP_OVERLOAD_SECURE_FUNC_1_2(__ret,__func,__type0,__arg0,__dsttype,__dst,__type1,__arg1,__type2,__arg2) \
  extern "C++" { \
    template <size_t __size> inline \
    __ret __cdecl __func(__type0 __arg0, __dsttype (&__dst)[__size], __type1 __arg1, __type2 __arg2) { \
      return __func(__arg0, __dst, __size, __arg1, __arg2); \
    } \
  }

#define __DEFINE_CPP_OVERLOAD_SECURE_FUNC_1_3(__ret,__func,__type0,__arg0,__dsttype,__dst,__type1,__arg1,__type2,__arg2,__type3,__arg3) \
  extern "C++" { \
    template <size_t __size> inline \
      __ret __cdecl __func(__type0 __arg0, __dsttype (&__dst)[__size], __type1 __arg1, __type2 __arg2, __type3 __arg3) { \
      return __func(__arg0, __dst, __size, __arg1, __arg2, __arg3); \
    } \
  }

#define __DEFINE_CPP_OVERLOAD_SECURE_FUNC_2_0(__ret,__func,__type1,__arg1,__type2,__arg2,__dsttype,__dst) \
  extern "C++" { \
    template <size_t __size> inline \
    __ret __cdecl __func(__type1 __arg1, __type2 __arg2, __dsttype (&__dst)[__size]) { \
      return __func(__arg1, __arg2, __dst, __size); \
    } \
  }

#define __DEFINE_CPP_OVERLOAD_SECURE_FUNC_0_1_ARGLIST(__ret,__func,__vfunc,__dsttype,__dst,__type1,__arg1) \
  extern "C++" {\
    template <size_t __size> \
    inline __ret __cdecl __func(__dsttype (&__dst)[__size], __type1 __arg1, ...) { \
      va_list __vaargs; \
      _crt_va_start(__vaargs, __arg1); \
      __ret __retval = __vfunc(__dst,__size,__arg1,__vaargs); \
      _crt_va_end(__vaargs); \
      return __retval; \
    }\
  }

#define __DEFINE_CPP_OVERLOAD_SECURE_FUNC_0_2_ARGLIST(__ret,__func,__vfunc,__dsttype,__dst,__type1,__arg1,__type2,__arg2) \
  extern "C++" {\
    template <size_t __size> \
    inline __ret __cdecl __func(__dsttype (&__dst)[__size], __type1 __arg1, __type2 __arg2, ...) { \
      va_list __vaargs; \
      _crt_va_start(__vaargs, __arg2); \
      __ret __retval = __vfunc(__dst,__size,__arg1,__arg2,__vaargs); \
      _crt_va_end(__vaargs); \
      return __retval; \
    }\
  }

#define __DEFINE_CPP_OVERLOAD_SECURE_FUNC_SPLITPATH(__ret,__func,__dsttype,__src) \
  extern "C++" { \
    template <size_t __drive_size, size_t __dir_size, size_t __name_size, size_t __ext_size> inline \
    __ret __cdecl __func(const __dsttype *__src, __dsttype (&__drive)[__drive_size], __dsttype (&__dir)[__dir_size], __dsttype (&__name)[__name_size], __dsttype (&__ext)[__ext_size]) { \
        return __func(__src, __drive, __drive_size, __dir, __dir_size, __name, __name_size, __ext, __ext_size); \
    } \
  }

#else

#define __DEFINE_CPP_OVERLOAD_SECURE_FUNC_0_0(__ret,__func,__dsttype,__dst)
#define __DEFINE_CPP_OVERLOAD_SECURE_FUNC_0_1(__ret,__func,__dsttype,__dst,__type1,__arg1)
#define __DEFINE_CPP_OVERLOAD_SECURE_FUNC_0_2(__ret,__func,__dsttype,__dst,__type1,__arg1,__type2,__arg2)
#define __DEFINE_CPP_OVERLOAD_SECURE_FUNC_0_3(__ret,__func,__dsttype,__dst,__type1,__arg1,__type2,__arg2,__type3,__arg3)
#define __DEFINE_CPP_OVERLOAD_SECURE_FUNC_0_4(__ret,__func,__dsttype,__dst,__type1,__arg1,__type2,__arg2,__type3,__arg3,__type4,__arg4)
#define __DEFINE_CPP_OVERLOAD_SECURE_FUNC_1_1(__ret,__func,__type0,__arg0,__dsttype,__dst,__type1,__arg1)
#define __DEFINE_CPP_OVERLOAD_SECURE_FUNC_1_2(__ret,__func,__type0,__arg0,__dsttype,__dst,__type1,__arg1,__type2,__arg2)
#define __DEFINE_CPP_OVERLOAD_SECURE_FUNC_1_3(__ret,__func,__type0,__arg0,__dsttype,__dst,__type1,__arg1,__type2,__arg2,__type3,__arg3)
#define __DEFINE_CPP_OVERLOAD_SECURE_FUNC_2_0(__ret,__func,__type1,__arg1,__type2,__arg2,__dsttype,__dst)
#define __DEFINE_CPP_OVERLOAD_SECURE_FUNC_0_1_ARGLIST(__ret,__func,__vfunc,__dsttype,__dst,__type1,__arg1)
#define __DEFINE_CPP_OVERLOAD_SECURE_FUNC_0_2_ARGLIST(__ret,__func,__vfunc,__dsttype,__dst,__type1,__arg1,__type2,__arg2)
#define __DEFINE_CPP_OVERLOAD_SECURE_FUNC_SPLITPATH(__ret,__func,__dsttype,__src)

#endif

#define __DEFINE_CPP_OVERLOAD_STANDARD_FUNC_0_0(__ret_type, __ret_policy, __decl_spec, __name, __dst_attr, __dst_type, __dst) \
    __DEFINE_CPP_OVERLOAD_STANDARD_FUNC_0_0_EX(__ret_type, __ret_policy, __decl_spec, __func_name, __func_name##_s, __dst_attr, __dst_type, __dst)
#define __DEFINE_CPP_OVERLOAD_STANDARD_FUNC_0_1(__ret_type, __ret_policy, __decl_spec, __name, __dst_attr, __dst_type, __dst, __arg1_type, __arg1) \
    __DEFINE_CPP_OVERLOAD_STANDARD_FUNC_0_2_EX(__ret_type, __ret_policy, __decl_spec, __func_name, __func_name##_s, __dst_attr, __dst_type, __dst, __arg1_type, __arg1, __arg2_type, __arg2)
#define __DEFINE_CPP_OVERLOAD_STANDARD_FUNC_0_2(__ret_type, __ret_policy, __decl_spec, __name, __dst_attr, __dst_type, __dst, __arg1_type, __arg1, __arg2_type, __arg2) \
    __DEFINE_CPP_OVERLOAD_STANDARD_FUNC_0_2_EX(__ret_type, __ret_policy, __decl_spec, __func_name, __func_name##_s, __dst_attr, __dst_type, __dst, __arg1_type, __arg1, __arg2_type, __arg2)
#define __DEFINE_CPP_OVERLOAD_STANDARD_FUNC_0_3(__ret_type, __ret_policy, __decl_spec, __name, __dst_attr, __dst_type, __dst, __arg1_type, __arg1, __arg2_type, __arg2, __arg3_type, __arg3) \
    __DEFINE_CPP_OVERLOAD_STANDARD_FUNC_0_3_EX(__ret_type, __ret_policy, __decl_spec, __func_name, __func_name##_s, __dst_attr, __dst_type, __dst, __arg1_type, __arg1, __arg2_type, __arg2, __arg3_type, __arg3)
#define __DEFINE_CPP_OVERLOAD_STANDARD_FUNC_0_4(__ret_type, __ret_policy, __decl_spec, __name, __dst_attr, __dst_type, __dst, __arg1_type, __arg1, __arg2_type, __arg2, __arg3_type, __arg3, __arg4_type, __arg4) \
    __DEFINE_CPP_OVERLOAD_STANDARD_FUNC_0_4_EX(__ret_type, __ret_policy, __decl_spec, __func_name, __func_name##_s, __dst_attr, __dst_type, __dst, __arg1_type, __arg1, __arg2_type, __arg2, __arg3_type, __arg3, __arg4_type, __arg4)

#if defined(__cplusplus) && _CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES

#define __RETURN_POLICY_SAME(__func_call, __dst) return (__func_call)
#define __RETURN_POLICY_DST(__func_call, __dst) return ((__func_call) == 0 ? __dst : 0)
#define __RETURN_POLICY_VOID(__func_call, __dst) (__func_call); return
#define __EMPTY_DECLSPEC

#define __DEFINE_CPP_OVERLOAD_STANDARD_FUNC_0_0_EX(__ret_type, __ret_policy, __decl_spec, __name, __sec_name, __dst_attr, __dst_type, __dst) \
    __inline __ret_type __CRTDECL __insecure_##__name(__dst_attr __dst_type *__dst) \
    { \
        __decl_spec __ret_type __cdecl __name(__dst_type *__dst); \
        return __name(__dst); \
    } \
    extern "C++" { \
    template <typename _T> \
    inline __ret_type __CRTDECL __name(_T &__dst) _CRT_SECURE_CPP_NOTHROW { \
        return __insecure_##__name(static_cast<__dst_type*>(__dst)); \
    } \
    template <typename _T> \
    inline __ret_type __CRTDECL __name(const _T &__dst) _CRT_SECURE_CPP_NOTHROW { \
        return __insecure_##__name(static_cast<__dst_type *>(__dst)); \
    } \
    template <> \
    inline __ret_type __CRTDECL __name(__dst_type *&__dst) _CRT_SECURE_CPP_NOTHROW { \
        return __insecure_##__name(__dst); \
    } \
    template <size_t __size> \
    inline __ret_type __CRTDECL __name(__dst_type (&__dst)[__size]) _CRT_SECURE_CPP_NOTHROW { \
        __ret_policy(__sec_name(__dst, __size), __dst); \
    } \
    }

#define __DEFINE_CPP_OVERLOAD_STANDARD_FUNC_0_2_EX(__ret_type, __ret_policy, __decl_spec, __name, __sec_name, __sec_dst_type, __dst_attr, __dst_type, __dst, __arg1_type, __arg1, __arg2_type, __arg2) \
    __inline __ret_type __CRTDECL __insecure_##__name(__dst_attr __dst_type *__dst, __arg1_type __arg1, __arg2_type __arg2) \
    { \
        __decl_spec __ret_type __cdecl __name(__dst_type *__dst, __arg1_type, __arg2_type); \
        return __name(__dst, __arg1, __arg2); \
    } \
    extern "C++" { \
    template <typename _T> \
    inline __ret_type __CRTDECL __name(_T &__dst, __arg1_type __arg1, __arg2_type __arg2) _CRT_SECURE_CPP_NOTHROW { \
        return __insecure_##__name(static_cast<__dst_type*>(__dst), __arg1, __arg2); \
    } \
    template <typename _T> \
    inline __ret_type __CRTDECL __name(const _T &__dst, __arg1_type __arg1, __arg2_type __arg2) _CRT_SECURE_CPP_NOTHROW { \
        return __insecure_##__name(static_cast<__dst_type *>(__dst), __arg1, __arg2); \
    } \
    template <> \
    inline __ret_type __CRTDECL __name(__dst_type *&__dst, __arg1_type __arg1, __arg2_type __arg2) _CRT_SECURE_CPP_NOTHROW { \
        return __insecure_##__name(__dst, __arg1, __arg2); \
    } \
    template <size_t __size> \
    inline __ret_type __CRTDECL __name(__sec_dst_type (&__dst)[__size], __arg1_type __arg1, __arg2_type __arg2) _CRT_SECURE_CPP_NOTHROW { \
        __ret_policy(__sec_name(__dst, __size), __dst); \
    } \
    }

#define __DEFINE_CPP_OVERLOAD_STANDARD_FUNC_0_1_EX(__ret_type, __ret_policy, __decl_spec, __name, __sec_name, __sec_dst_type, __dst_attr, __dst_type, __dst, __arg1_type, __arg1) \
    __inline __ret_type __CRTDECL __insecure_##__name(__dst_attr __dst_type *__dst, __arg1_type __arg1) \
    { \
        __decl_spec __ret_type __cdecl __name(__dst_type *__dst, __arg1_type); \
        return __name(__dst, __arg1); \
    } \
    extern "C++" { \
    template <typename _T> \
    inline __ret_type __CRTDECL __name(_T &__dst, __arg1_type __arg1) _CRT_SECURE_CPP_NOTHROW { \
        return __insecure_##__name(static_cast<__dst_type*>(__dst), __arg1); \
    } \
    template <typename _T> \
    inline __ret_type __CRTDECL __name(const _T &__dst, __arg1_type __arg1) _CRT_SECURE_CPP_NOTHROW { \
        return __insecure_##__name(static_cast<__dst_type *>(__dst), __arg1); \
    } \
    template <> \
    inline __ret_type __CRTDECL __name(__dst_type *&__dst, __arg1_type __arg1) _CRT_SECURE_CPP_NOTHROW { \
        return __insecure_##__name(__dst, __arg1); \
    } \
    template <size_t __size> \
    inline __ret_type __CRTDECL __name(__sec_dst_type (&__dst)[__size], __arg1_type __arg1) _CRT_SECURE_CPP_NOTHROW { \
        __ret_policy(__sec_name(__dst, __size), __dst); \
    } \
    }

#define __DEFINE_CPP_OVERLOAD_STANDARD_FUNC_0_3_EX(__ret_type, __ret_policy, __decl_spec, __name, __sec_name, __sec_dst_type, __dst_attr, __dst_type, __dst, __arg1_type, __arg1, __arg2_type, __arg2, __arg3_type, __arg3) \
    __inline __ret_type __CRTDECL __insecure_##__name(__dst_attr __dst_type *__dst, __arg1_type __arg1, __arg2_type __arg2, __arg3_type __arg3) \
    { \
        __decl_spec __ret_type __cdecl __name(__dst_type *__dst, __arg1_type, __arg2_type, __arg3_type); \
        return __name(__dst, __arg1, __arg2, __arg3); \
    } \
    extern "C++" { \
    template <typename _T> \
    inline __ret_type __CRTDECL __name(_T &__dst, __arg1_type __arg1, __arg2_type __arg2, __arg3_type __arg3) _CRT_SECURE_CPP_NOTHROW { \
        return __insecure_##__name(static_cast<__dst_type*>(__dst), __arg1, __arg2, __arg3); \
    } \
    template <typename _T> \
    inline __ret_type __CRTDECL __name(const _T &__dst, __arg1_type __arg1, __arg2_type __arg2, __arg3_type __arg3) _CRT_SECURE_CPP_NOTHROW { \
        return __insecure_##__name(static_cast<__dst_type *>(__dst), __arg1, __arg2, __arg3); \
    } \
    template <> \
    inline __ret_type __CRTDECL __name(__dst_type *&__dst, __arg1_type __arg1, __arg2_type __arg2, __arg3_type __arg3) _CRT_SECURE_CPP_NOTHROW { \
        return __insecure_##__name(__dst, __arg1, __arg2, __arg3); \
    } \
    template <size_t __size> \
    inline __ret_type __CRTDECL __name(__sec_dst_type (&__dst)[__size], __arg1_type __arg1, __arg2_type __arg2, __arg3_type __arg3) _CRT_SECURE_CPP_NOTHROW { \
        __ret_policy(__sec_name(__dst, __size), __dst); \
    } \
    }

#define __DEFINE_CPP_OVERLOAD_STANDARD_FUNC_0_4_EX(__ret_type, __ret_policy, __decl_spec, __name, __sec_name, __sec_dst_type, __dst_attr, __dst_type, __dst, __arg1_type, __arg1, __arg2_type, __arg2, __arg3_type, __arg3, __arg4_type, __arg4) \
    __inline __ret_type __CRTDECL __insecure_##__name(__dst_attr __dst_type *__dst, __arg1_type __arg1, __arg2_type __arg2, __arg3_type __arg3, __arg4_type __arg4) \
    { \
        __decl_spec __ret_type __cdecl __name(__dst_type *__dst, __arg1_type, __arg2_type, __arg3_type, __arg4_type); \
        return __name(__dst, __arg1, __arg2, __arg3, __arg4); \
    } \
    extern "C++" { \
    template <typename _T> \
    inline __ret_type __CRTDECL __name(_T &__dst, __arg1_type __arg1, __arg2_type __arg2, __arg3_type __arg3, __arg4_type __arg4) _CRT_SECURE_CPP_NOTHROW { \
        return __insecure_##__name(static_cast<__dst_type*>(__dst), __arg1, __arg2, __arg3, __arg4); \
    } \
    template <typename _T> \
    inline __ret_type __CRTDECL __name(const _T &__dst, __arg1_type __arg1, __arg2_type __arg2, __arg3_type __arg3, __arg4_type __arg4) _CRT_SECURE_CPP_NOTHROW { \
        return __insecure_##__name(static_cast<__dst_type *>(__dst), __arg1, __arg2, __arg3, __arg4); \
    } \
    template <> \
    inline __ret_type __CRTDECL __name(__dst_type *&__dst, __arg1_type __arg1, __arg2_type __arg2, __arg3_type __arg3, __arg4_type __arg4) _CRT_SECURE_CPP_NOTHROW { \
        return __insecure_##__name(__dst, __arg1, __arg2, __arg3, __arg4); \
    } \
    template <size_t __size> \
    inline __ret_type __CRTDECL __name(__sec_dst_type (&__dst)[__size], __arg1_type __arg1, __arg2_type __arg2, __arg3_type __arg3, __arg4_type __arg4) _CRT_SECURE_CPP_NOTHROW { \
        __ret_policy(__sec_name(__dst, __size)); \
    } \
    }

#else

#define __DEFINE_CPP_OVERLOAD_STANDARD_FUNC_0_0_EX(__ret_type, __ret_policy, __decl_spec, __name, __sec_name, __dst_attr, __dst_type, __dst)
#define __DEFINE_CPP_OVERLOAD_STANDARD_FUNC_0_1_EX(__ret_type, __ret_policy, __decl_spec, __name, __sec_name, __dst_attr, __dst_type, __dst, __arg1_type, __arg1)
#define __DEFINE_CPP_OVERLOAD_STANDARD_FUNC_0_2_EX(__ret_type, __ret_policy, __decl_spec, __name, __sec_name, __dst_attr, __dst_type, __dst, __arg1_type, __arg1, __arg2_type, __arg2)
#define __DEFINE_CPP_OVERLOAD_STANDARD_FUNC_0_3_EX(__ret_type, __ret_policy, __decl_spec, __name, __sec_name, __dst_attr, __dst_type, __dst, __arg1_type, __arg1, __arg2_type, __arg2, __arg3_type, __arg3)
#define __DEFINE_CPP_OVERLOAD_STANDARD_FUNC_0_4_EX(__ret_type, __ret_policy, __decl_spec, __name, __sec_name, __dst_attr, __dst_type, __dst, __arg1_type, __arg1, __arg2_type, __arg2, __arg3_type, __arg3, __arg4_type, __arg4)

#endif

struct threadlocaleinfostruct;
struct threadmbcinfostruct;
typedef struct threadlocaleinfostruct *pthreadlocinfo;
typedef struct threadmbcinfostruct *pthreadmbcinfo;
struct __lc_time_data;

typedef struct localeinfo_struct {
  pthreadlocinfo locinfo;
  pthreadmbcinfo mbcinfo;
} _locale_tstruct,*_locale_t;

#ifndef _TAGLC_ID_DEFINED
#define _TAGLC_ID_DEFINED
typedef struct tagLC_ID {
  unsigned short wLanguage;
  unsigned short wCountry;
  unsigned short wCodePage;
} LC_ID,*LPLC_ID;
#endif /* _TAGLC_ID_DEFINED */

#ifndef _THREADLOCALEINFO
#define _THREADLOCALEINFO
typedef struct threadlocaleinfostruct {
  int refcount;
  unsigned int lc_codepage;
  unsigned int lc_collate_cp;
  unsigned long lc_handle[6];
  LC_ID lc_id[6];
  struct {
    char *locale;
    wchar_t *wlocale;
    int *refcount;
    int *wrefcount;
  } lc_category[6];
  int lc_clike;
  int mb_cur_max;
  int *lconv_intl_refcount;
  int *lconv_num_refcount;
  int *lconv_mon_refcount;
  struct lconv *lconv;
  int *ctype1_refcount;
  unsigned short *ctype1;
  const unsigned short *pctype;
  const unsigned char *pclmap;
  const unsigned char *pcumap;
  struct __lc_time_data *lc_time_curr;
} threadlocinfo;
#endif /* _THREADLOCALEINFO */

#ifndef __crt_typefix
#define __crt_typefix(ctype)
#endif

#ifndef __WIDL__
#pragma pack(pop)
#endif

#endif /* _INC_CRTDEFS */
