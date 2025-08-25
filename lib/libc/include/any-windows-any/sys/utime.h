/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_UTIME
#define _INC_UTIME

#ifndef _WIN32
#error Only Win32 target is supported!
#endif

#include <crtdefs.h>

#pragma pack(push,_CRT_PACKING)

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _CRTIMP
#define _CRTIMP __declspec(dllimport)
#endif

#ifndef _WCHAR_T_DEFINED
  typedef unsigned short wchar_t;
#define _WCHAR_T_DEFINED
#endif

#ifdef _USE_32BIT_TIME_T
#ifdef _WIN64
#undef _USE_32BIT_TIME_T
#endif
#endif

#ifndef _TIME32_T_DEFINED
#define _TIME32_T_DEFINED
  typedef long __time32_t;
#endif

#ifndef _TIME64_T_DEFINED
#define _TIME64_T_DEFINED
  __MINGW_EXTENSION typedef __int64 __time64_t;
#endif

#ifndef _TIME_T_DEFINED
#define _TIME_T_DEFINED
#ifdef _USE_32BIT_TIME_T
  typedef __time32_t time_t;
#else
  typedef __time64_t time_t;
#endif
#endif

#ifndef _UTIMBUF_DEFINED
#define _UTIMBUF_DEFINED

  struct _utimbuf {
    time_t actime;
    time_t modtime;
  };

  struct __utimbuf32 {
    __time32_t actime;
    __time32_t modtime;
  };

  struct __utimbuf64 {
    __time64_t actime;
    __time64_t modtime;
  };

#ifndef	NO_OLDNAMES
  struct utimbuf {
    time_t actime;
    time_t modtime;
  };

  struct utimbuf32 {
    __time32_t actime;
    __time32_t modtime;
  };
#endif
#endif

  _CRTIMP int __cdecl _utime32(const char *_Filename,struct __utimbuf32 *_Time);
  _CRTIMP int __cdecl _futime32(int _FileDes,struct __utimbuf32 *_Time);
  _CRTIMP int __cdecl _wutime32(const wchar_t *_Filename,struct __utimbuf32 *_Time);
  _CRTIMP int __cdecl _utime64(const char *_Filename,struct __utimbuf64 *_Time);
  _CRTIMP int __cdecl _futime64(int _FileDes,struct __utimbuf64 *_Time);
  _CRTIMP int __cdecl _wutime64(const wchar_t *_Filename,struct __utimbuf64 *_Time);

#ifndef RC_INVOKED
int __cdecl _utime(const char *,struct _utimbuf *);
int __cdecl _futime(int,struct _utimbuf *);
int __cdecl _wutime(const wchar_t *,struct _utimbuf *);
#ifndef __CRT__NO_INLINE
#ifdef _USE_32BIT_TIME_T
__CRT_INLINE int __cdecl _utime(const char *_Filename,struct _utimbuf *_Utimbuf) {
  return _utime32(_Filename,(struct __utimbuf32 *)_Utimbuf);
}
__CRT_INLINE int __cdecl _futime(int _Desc,struct _utimbuf *_Utimbuf) {
  return _futime32(_Desc,(struct __utimbuf32 *)_Utimbuf);
}
__CRT_INLINE int __cdecl _wutime(const wchar_t *_Filename,struct _utimbuf *_Utimbuf) {
  return _wutime32(_Filename,(struct __utimbuf32 *)_Utimbuf);
}
#else
__CRT_INLINE int __cdecl _utime(const char *_Filename,struct _utimbuf *_Utimbuf) {
  return _utime64(_Filename,(struct __utimbuf64 *)_Utimbuf);
}
__CRT_INLINE int __cdecl _futime(int _Desc,struct _utimbuf *_Utimbuf) {
  return _futime64(_Desc,(struct __utimbuf64 *)_Utimbuf);
}
__CRT_INLINE int __cdecl _wutime(const wchar_t *_Filename,struct _utimbuf *_Utimbuf) {
  return _wutime64(_Filename,(struct __utimbuf64 *)_Utimbuf);
}
#endif
#endif /* !__CRT__NO_INLINE */

#ifndef	NO_OLDNAMES
  int __cdecl utime(const char *, struct utimbuf *);
#ifndef __CRT__NO_INLINE
#ifndef _USE_32BIT_TIME_T
__CRT_INLINE int __cdecl utime(const char *_Filename,struct utimbuf *_Utimbuf) {
  return _utime64(_Filename,(struct __utimbuf64 *)_Utimbuf);
}
#endif /* !_USE_32BIT_TIME_T */
#endif /* !__CRT__NO_INLINE */
#endif
#endif

#ifdef __cplusplus
}
#endif

#pragma pack(pop)
#endif
