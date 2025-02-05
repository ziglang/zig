/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _INC_SWPRINTF_INL
#define _INC_SWPRINTF_INL

#include <vadefs.h>

__mingw_ovr
/* __attribute__((__format__ (gnu_wprintf, 3, 0))) */ __MINGW_ATTRIB_NONNULL(3)
int vswprintf (wchar_t *__stream, size_t __count, const wchar_t *__format, __builtin_va_list __local_argv)
{
  return vsnwprintf( __stream, __count, __format, __local_argv );
}

__mingw_ovr
/* __attribute__((__format__ (gnu_wprintf, 3, 4))) */ __MINGW_ATTRIB_NONNULL(3)
int swprintf (wchar_t *__stream, size_t __count, const wchar_t *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv;

  __builtin_va_start( __local_argv, __format );
  __retval = vswprintf( __stream, __count, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

#ifdef __cplusplus

extern "C++" {

__mingw_ovr
/* __attribute__((__format__ (gnu_wprintf, 2, 0))) */ __MINGW_ATTRIB_NONNULL(2)
int vswprintf (wchar_t *__stream, const wchar_t *__format, __builtin_va_list __local_argv)
{
#if __USE_MINGW_ANSI_STDIO
  return __mingw_vswprintf( __stream, __format, __local_argv );
#else
  return _vswprintf( __stream, __format, __local_argv );
#endif
}

__mingw_ovr
/* __attribute__((__format__ (gnu_wprintf, 2, 3))) */ __MINGW_ATTRIB_NONNULL(2)
int swprintf (wchar_t *__stream, const wchar_t *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv;

  __builtin_va_start( __local_argv, __format );
  __retval = vswprintf( __stream, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

}

#elif defined(_CRT_NON_CONFORMING_SWPRINTFS)

#if __USE_MINGW_ANSI_STDIO
#define swprintf __mingw_swprintf
#define vswprintf __mingw_vswprintf
#else
#define swprintf _swprintf
#define vswprintf _vswprintf
#endif

#endif /* __cplusplus */

#endif /* _INC_SWPRINTF_INL */
