/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
 
#ifndef _INC_MINGW_SECAPI
#define _INC_MINGW_SECAPI

/* http://msdn.microsoft.com/en-us/library/ms175759%28v=VS.100%29.aspx */
#if defined(__cplusplus)
#ifndef _CRT_SECURE_CPP_OVERLOAD_SECURE_NAMES
#define _CRT_SECURE_CPP_OVERLOAD_SECURE_NAMES 1         /* default to 1 */
#endif /*_CRT_SECURE_CPP_OVERLOAD_SECURE_NAMES*/
#ifndef _CRT_SECURE_CPP_OVERLOAD_SECURE_NAMES_MEMORY
#define _CRT_SECURE_CPP_OVERLOAD_SECURE_NAMES_MEMORY 0  /* default to 0 */
#endif /*_CRT_SECURE_CPP_OVERLOAD_SECURE_NAMES_MEMORY*/
#ifndef _CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES
#define _CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES 0       /* default to 0 */
#endif /* _CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES */
#ifndef _CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES_COUNT
#define _CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES_COUNT 0 /* default to 0 */
#endif /* _CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES_COUNT */
#ifndef _CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES_MEMORY
#define _CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES_MEMORY 0 /* default to 0 */
#endif /* _CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES_MEMORY */
#else
/* Templates won't work in C, will break if secure API is not enabled, disabled */
#undef _CRT_SECURE_CPP_OVERLOAD_SECURE_NAMES
#undef _CRT_SECURE_CPP_OVERLOAD_SECURE_NAMES_MEMORY
#undef _CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES
#undef _CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES_COUNT
#undef _CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES_MEMORY
#define _CRT_SECURE_CPP_OVERLOAD_SECURE_NAMES 0
#define _CRT_SECURE_CPP_OVERLOAD_SECURE_NAMES_MEMORY 0
#define _CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES 0
#define _CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES_COUNT 0
#define _CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES_MEMORY 0
#endif /*defined(__cplusplus)*/

#define __MINGW_CRT_NAME_CONCAT2(sym) ::sym##_s

#ifdef __cplusplus
extern "C++" {
template <bool __test, typename __dsttype>
  struct __if_array;
template <typename __dsttype>
  struct __if_array <true, __dsttype> {
    typedef __dsttype __type;
};
}
#endif /*__cplusplus*/

/* https://blogs.msdn.com/b/sdl/archive/2010/02/16/vc-2010-and-memcpy.aspx?Redirected=true */
/* fallback on default implementation if we can't know the size of the destination */
#if (_CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES_MEMORY == 1)
#define __CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES_MEMORY_0_3_(__ret,__func,__type1,__attrib1,__arg1,__type2,__attrib2,__arg2,__type3,__attrib3,__arg3)\
  extern "C" {_CRTIMP __ret __cdecl __func(__type1 * __attrib1 __arg1, __type2 __attrib2 __arg2, __type3 __attrib3 __arg3) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;}\
  extern "C++" {\
    template <size_t __size, typename __dsttype> inline\
    typename __if_array < (__size > 1), void * >::__type __cdecl __func(\
    __dsttype (&__arg1)[__size],\
    __type2 __attrib2 (__arg2),\
    __type3 __attrib3 (__arg3)) {\
      return __MINGW_CRT_NAME_CONCAT2(__func) (__arg1,__size * sizeof(__dsttype),__arg2,__arg3) == 0 ? __arg1 : NULL;\
    }\
  }
#else
#define __CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES_MEMORY_0_3_(__ret,__func,__type1,__attrib1,__arg1,__type2,__attrib2,__arg2,__type3,__attrib3,__arg3)\
  _CRTIMP __ret __cdecl __func(__type1 * __attrib1 __arg1, __type2 __attrib2 __arg2, __type3 __attrib3 __arg3) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
#endif

#endif /*_INC_MINGW_SECAPI*/
