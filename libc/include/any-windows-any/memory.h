/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_MEMORY
#define _INC_MEMORY

#include <crtdefs.h>

#if defined(__LIBMSVCRT__)
/* When building mingw-w64, this should be blank.  */
#define _SECIMP
#else
#ifndef _SECIMP
#define _SECIMP __declspec(dllimport)
#endif /* _SECIMP */
#endif /* defined(_CRTBLD) || defined(__LIBMSVCRT__) */

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _CONST_RETURN
#define _CONST_RETURN
#endif

#define _WConst_return _CONST_RETURN

#ifndef _CRT_MEMORY_DEFINED
#define _CRT_MEMORY_DEFINED
  _CRTIMP void *__cdecl _memccpy(void *_Dst,const void *_Src,int _Val,size_t _MaxCount);
  _CONST_RETURN void *__cdecl memchr(const void *_Buf ,int _Val,size_t _MaxCount);
  _CRTIMP int __cdecl _memicmp(const void *_Buf1,const void *_Buf2,size_t _Size);
  _CRTIMP int __cdecl _memicmp_l(const void *_Buf1,const void *_Buf2,size_t _Size,_locale_t _Locale);
  int __cdecl memcmp(const void *_Buf1,const void *_Buf2,size_t _Size);
  void * __cdecl memcpy(void * __restrict__ _Dst,const void * __restrict__ _Src,size_t _Size) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _SECIMP errno_t __cdecl memcpy_s (void *_dest,size_t _numberOfElements,const void *_src,size_t _count);
  void * __cdecl mempcpy (void *_Dst, const void *_Src, size_t _Size);
  void * __cdecl memset(void *_Dst,int _Val,size_t _Size);

#ifndef	NO_OLDNAMES
  void * __cdecl memccpy(void *_Dst,const void *_Src,int _Val,size_t _Size) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  int __cdecl memicmp(const void *_Buf1,const void *_Buf2,size_t _Size) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
