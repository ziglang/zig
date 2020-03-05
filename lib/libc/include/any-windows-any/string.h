/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_STRING
#define _INC_STRING

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

#ifndef _NLSCMP_DEFINED
#define _NLSCMP_DEFINED
#define _NLSCMPERROR 2147483647
#endif

#ifndef NULL
#ifdef __cplusplus
#ifndef _WIN64
#define NULL 0
#else
#define NULL 0LL
#endif  /* W64 */
#else
#define NULL ((void *)0)
#endif
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
  char * __cdecl _strset(char *_Str,int _Val) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  char * __cdecl _strset_l(char *_Str,int _Val,_locale_t _Locale) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  char * __cdecl strcpy(char * __restrict__ _Dest,const char * __restrict__ _Source);
  char * __cdecl strcat(char * __restrict__ _Dest,const char * __restrict__ _Source);
  int __cdecl strcmp(const char *_Str1,const char *_Str2);
  size_t __cdecl strlen(const char *_Str);
  size_t __cdecl strnlen(const char *_Str,size_t _MaxCount);
  void *__cdecl memmove(void *_Dst,const void *_Src,size_t _Size) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP char *__cdecl _strdup(const char *_Src);
  _CONST_RETURN char *__cdecl strchr(const char *_Str,int _Val);
  _CRTIMP int __cdecl _stricmp(const char *_Str1,const char *_Str2);
  _CRTIMP int __cdecl _strcmpi(const char *_Str1,const char *_Str2);
  _CRTIMP int __cdecl _stricmp_l(const char *_Str1,const char *_Str2,_locale_t _Locale);
  int __cdecl strcoll(const char *_Str1,const char *_Str2);
  _CRTIMP int __cdecl _strcoll_l(const char *_Str1,const char *_Str2,_locale_t _Locale);
  _CRTIMP int __cdecl _stricoll(const char *_Str1,const char *_Str2);
  _CRTIMP int __cdecl _stricoll_l(const char *_Str1,const char *_Str2,_locale_t _Locale);
  _CRTIMP int __cdecl _strncoll (const char *_Str1,const char *_Str2,size_t _MaxCount);
  _CRTIMP int __cdecl _strncoll_l(const char *_Str1,const char *_Str2,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP int __cdecl _strnicoll (const char *_Str1,const char *_Str2,size_t _MaxCount);
  _CRTIMP int __cdecl _strnicoll_l(const char *_Str1,const char *_Str2,size_t _MaxCount,_locale_t _Locale);
  size_t __cdecl strcspn(const char *_Str,const char *_Control);
  _CRTIMP char *__cdecl _strerror(const char *_ErrMsg) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  char *__cdecl strerror(int) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP char *__cdecl _strlwr(char *_String) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  char *strlwr_l(char *_String,_locale_t _Locale) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  char *__cdecl strncat(char * __restrict__ _Dest,const char * __restrict__ _Source,size_t _Count) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  int __cdecl strncmp(const char *_Str1,const char *_Str2,size_t _MaxCount);
  _CRTIMP int __cdecl _strnicmp(const char *_Str1,const char *_Str2,size_t _MaxCount);
  _CRTIMP int __cdecl _strnicmp_l(const char *_Str1,const char *_Str2,size_t _MaxCount,_locale_t _Locale);
  char *strncpy(char * __restrict__ _Dest,const char * __restrict__ _Source,size_t _Count) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP char *__cdecl _strnset(char *_Str,int _Val,size_t _MaxCount) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP char *__cdecl _strnset_l(char *str,int c,size_t count,_locale_t _Locale) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CONST_RETURN char *__cdecl strpbrk(const char *_Str,const char *_Control);
  _CONST_RETURN char *__cdecl strrchr(const char *_Str,int _Ch);
  _CRTIMP char *__cdecl _strrev(char *_Str);
  size_t __cdecl strspn(const char *_Str,const char *_Control);
  _CONST_RETURN char *__cdecl strstr(const char *_Str,const char *_SubStr);
  char *__cdecl strtok(char * __restrict__ _Str,const char * __restrict__ _Delim) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
#pragma push_macro("strtok_r")
#undef strtok_r
  char *strtok_r(char * __restrict__ _Str, const char * __restrict__ _Delim, char ** __restrict__ __last);
#pragma pop_macro("strtok_r")
  _CRTIMP char *__cdecl _strupr(char *_String) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP char *_strupr_l(char *_String,_locale_t _Locale) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  size_t __cdecl strxfrm(char * __restrict__ _Dst,const char * __restrict__ _Src,size_t _MaxCount);
  _CRTIMP size_t __cdecl _strxfrm_l(char * __restrict__ _Dst,const char * __restrict__ _Src,size_t _MaxCount,_locale_t _Locale);

#ifndef	NO_OLDNAMES
  char *__cdecl strdup(const char *_Src) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  int __cdecl strcmpi(const char *_Str1,const char *_Str2) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  int __cdecl stricmp(const char *_Str1,const char *_Str2) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  char *__cdecl strlwr(char *_Str) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  int __cdecl strnicmp(const char *_Str1,const char *_Str,size_t _MaxCount) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  int __cdecl strncasecmp (const char *, const char *, size_t);
  int __cdecl strcasecmp (const char *, const char *);
#ifndef __CRT__NO_INLINE
  __CRT_INLINE int __cdecl strncasecmp (const char *__sz1, const char *__sz2, size_t __sizeMaxCompare) { return _strnicmp (__sz1, __sz2, __sizeMaxCompare); }
  __CRT_INLINE int __cdecl strcasecmp (const char *__sz1, const char *__sz2) { return _stricmp (__sz1, __sz2); }
#else
#define strncasecmp _strnicmp
#define strcasecmp _stricmp
#endif /* !__CRT__NO_INLINE */
  char *__cdecl strnset(char *_Str,int _Val,size_t _MaxCount) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  char *__cdecl strrev(char *_Str) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  char *__cdecl strset(char *_Str,int _Val) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  char *__cdecl strupr(char *_Str) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
#endif

#ifndef _WSTRING_DEFINED
#define _WSTRING_DEFINED

  _CRTIMP wchar_t *__cdecl _wcsdup(const wchar_t *_Str);
  wchar_t *__cdecl wcscat(wchar_t * __restrict__ _Dest,const wchar_t * __restrict__ _Source) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CONST_RETURN wchar_t *__cdecl wcschr(const wchar_t *_Str,wchar_t _Ch);
  int __cdecl wcscmp(const wchar_t *_Str1,const wchar_t *_Str2);
  wchar_t *__cdecl wcscpy(wchar_t * __restrict__ _Dest,const wchar_t * __restrict__ _Source) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  size_t __cdecl wcscspn(const wchar_t *_Str,const wchar_t *_Control);
  size_t __cdecl wcslen(const wchar_t *_Str);
  size_t __cdecl wcsnlen(const wchar_t *_Src,size_t _MaxCount);
  wchar_t *wcsncat(wchar_t * __restrict__ _Dest,const wchar_t * __restrict__ _Source,size_t _Count) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  int __cdecl wcsncmp(const wchar_t *_Str1,const wchar_t *_Str2,size_t _MaxCount);
  wchar_t *wcsncpy(wchar_t * __restrict__ _Dest,const wchar_t * __restrict__ _Source,size_t _Count) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  wchar_t *__cdecl _wcsncpy_l(wchar_t * __restrict__ _Dest,const wchar_t * __restrict__ _Source,size_t _Count,_locale_t _Locale) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CONST_RETURN wchar_t *__cdecl wcspbrk(const wchar_t *_Str,const wchar_t *_Control);
  _CONST_RETURN wchar_t *__cdecl wcsrchr(const wchar_t *_Str,wchar_t _Ch);
  size_t __cdecl wcsspn(const wchar_t *_Str,const wchar_t *_Control);
  _CONST_RETURN wchar_t *__cdecl wcsstr(const wchar_t *_Str,const wchar_t *_SubStr);
  wchar_t *__cdecl wcstok(wchar_t * __restrict__ _Str,const wchar_t * __restrict__ _Delim) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP wchar_t *__cdecl _wcserror(int _ErrNum) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP wchar_t *__cdecl __wcserror(const wchar_t *_Str) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP int __cdecl _wcsicmp(const wchar_t *_Str1,const wchar_t *_Str2);
  _CRTIMP int __cdecl _wcsicmp_l(const wchar_t *_Str1,const wchar_t *_Str2,_locale_t _Locale);
  _CRTIMP int __cdecl _wcsnicmp(const wchar_t *_Str1,const wchar_t *_Str2,size_t _MaxCount);
  _CRTIMP int __cdecl _wcsnicmp_l(const wchar_t *_Str1,const wchar_t *_Str2,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP wchar_t *__cdecl _wcsnset(wchar_t *_Str,wchar_t _Val,size_t _MaxCount) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP wchar_t *__cdecl _wcsrev(wchar_t *_Str);
  _CRTIMP wchar_t *__cdecl _wcsset(wchar_t *_Str,wchar_t _Val) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP wchar_t *__cdecl _wcslwr(wchar_t *_String) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP wchar_t *_wcslwr_l(wchar_t *_String,_locale_t _Locale) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP wchar_t *__cdecl _wcsupr(wchar_t *_String) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP wchar_t *_wcsupr_l(wchar_t *_String,_locale_t _Locale) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  size_t __cdecl wcsxfrm(wchar_t * __restrict__ _Dst,const wchar_t * __restrict__ _Src,size_t _MaxCount);
  _CRTIMP size_t __cdecl _wcsxfrm_l(wchar_t * __restrict__ _Dst,const wchar_t * __restrict__ _Src,size_t _MaxCount,_locale_t _Locale);
  int __cdecl wcscoll(const wchar_t *_Str1,const wchar_t *_Str2);
  _CRTIMP int __cdecl _wcscoll_l(const wchar_t *_Str1,const wchar_t *_Str2,_locale_t _Locale);
  _CRTIMP int __cdecl _wcsicoll(const wchar_t *_Str1,const wchar_t *_Str2);
  _CRTIMP int __cdecl _wcsicoll_l(const wchar_t *_Str1,const wchar_t *_Str2,_locale_t _Locale);
  _CRTIMP int __cdecl _wcsncoll(const wchar_t *_Str1,const wchar_t *_Str2,size_t _MaxCount);
  _CRTIMP int __cdecl _wcsncoll_l(const wchar_t *_Str1,const wchar_t *_Str2,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP int __cdecl _wcsnicoll(const wchar_t *_Str1,const wchar_t *_Str2,size_t _MaxCount);
  _CRTIMP int __cdecl _wcsnicoll_l(const wchar_t *_Str1,const wchar_t *_Str2,size_t _MaxCount,_locale_t _Locale);

#ifndef	NO_OLDNAMES
  wchar_t *__cdecl wcsdup(const wchar_t *_Str) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
#define wcswcs wcsstr
  int __cdecl wcsicmp(const wchar_t *_Str1,const wchar_t *_Str2) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  int __cdecl wcsnicmp(const wchar_t *_Str1,const wchar_t *_Str2,size_t _MaxCount) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  wchar_t *__cdecl wcsnset(wchar_t *_Str,wchar_t _Val,size_t _MaxCount) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  wchar_t *__cdecl wcsrev(wchar_t *_Str) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  wchar_t *__cdecl wcsset(wchar_t *_Str,wchar_t _Val) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  wchar_t *__cdecl wcslwr(wchar_t *_Str) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  wchar_t *__cdecl wcsupr(wchar_t *_Str) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  int __cdecl wcsicoll(const wchar_t *_Str1,const wchar_t *_Str2) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
#endif
#endif

#ifdef __cplusplus
}
#endif

#include <sec_api/string_s.h>

#if __MINGW_FORTIFY_LEVEL > 0
#ifdef __cplusplus
extern "C" {
#endif

__mingw_bos_declare;

__mingw_bos_extern_ovr
void * memcpy(void * __restrict__ __dst, const void * __restrict__ __src, size_t __n)
{
  return __builtin___memcpy_chk(__dst, __src, __n, __mingw_bos(__dst, 0));
}

__mingw_bos_extern_ovr
void * memset(void * __dst, int __val, size_t __n)
{
  return __builtin___memset_chk(__dst, __val, __n, __mingw_bos(__dst, 0));
}

__mingw_bos_extern_ovr
void * memmove(void * __dst, const void * __src, size_t __n)
{
  return __builtin___memmove_chk(__dst, __src, __n, __mingw_bos(__dst, 0));
}

#ifdef _GNU_SOURCE
__mingw_bos_extern_ovr
void * mempcpy(void * __dst, const void * __src, size_t __n)
{
  return __builtin___mempcpy_chk(__dst, __src, __n, __mingw_bos(__dst, 0));
}
#endif /* _GNU_SOURCE */

__mingw_bos_extern_ovr
char * strcpy(char * __restrict__ __dst, const char * __restrict__ __src)
{
  return __builtin___strcpy_chk(__dst, __src, __mingw_bos(__dst, 1));
}

__mingw_bos_extern_ovr
char * strcat(char * __restrict__ __dst, const char * __restrict__ __src)
{
  return __builtin___strcat_chk(__dst, __src, __mingw_bos(__dst, 1));
}

__mingw_bos_extern_ovr
char * strncpy(char * __restrict__ __dst, const char * __restrict__ __src, size_t __n)
{
  return __builtin___strncpy_chk(__dst, __src, __n, __mingw_bos(__dst, 1));
}

__mingw_bos_extern_ovr
char * strncat(char * __restrict__ __dst, const char * __restrict__ __src, size_t __n)
{
  return __builtin___strncat_chk(__dst, __src, __n, __mingw_bos(__dst, 1));
}

_SECIMP errno_t __cdecl __mingw_call_memcpy_s(void *, size_t, const void *, size_t) __MINGW_ASM_CRT_CALL(memcpy_s);
wchar_t * __cdecl __mingw_call_wcscpy(wchar_t * __restrict__, const wchar_t * __restrict__) __MINGW_ASM_CALL(wcscpy);
wchar_t * __cdecl __mingw_call_wcscat(wchar_t * __restrict__, const wchar_t * __restrict__) __MINGW_ASM_CALL(wcscat);

__mingw_bos_extern_ovr
errno_t memcpy_s(void * __dst, size_t __os, const void * __src, size_t __n)
{
  __mingw_bos_ptr_chk_warn(__dst, __os, 0);
  return __mingw_call_memcpy_s(__dst, __os, __src, __n);
}

__mingw_bos_extern_ovr
wchar_t * wcscpy(wchar_t * __restrict__ __dst, const wchar_t * __restrict__ __src)
{
  if (__mingw_bos_known(__dst)) {
    __mingw_bos_cond_chk(!wcscpy_s(__dst, __mingw_bos(__dst, 1) / sizeof(wchar_t), __src));
    return __dst;
  }
  return __mingw_call_wcscpy(__dst, __src);
}

__mingw_bos_extern_ovr
wchar_t * wcscat(wchar_t * __restrict__ __dst, const wchar_t * __restrict__ __src)
{
  if (__mingw_bos_known(__dst)) {
    __mingw_bos_cond_chk(!wcscat_s(__dst, __mingw_bos(__dst, 1) / sizeof(wchar_t), __src));
    return __dst;
  }
  return __mingw_call_wcscat(__dst, __src);
}

#ifdef __cplusplus
}
#endif
#endif /* __MINGW_FORTIFY_LEVEL > 0 */

#endif
