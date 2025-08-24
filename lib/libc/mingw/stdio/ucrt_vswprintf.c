/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#undef __MSVCRT_VERSION__
#define _UCRT
#include <stdio.h>

int __cdecl vswprintf(wchar_t * __restrict__ _Dest,size_t _Count,const wchar_t * __restrict__ _Format,va_list _Args)
{
  int __ret;
  /*
   * __stdio_common_vswprintf() for case _Dest == NULL and _Count == 0 and
   * without _CRT_INTERNAL_PRINTF_STANDARD_SNPRINTF_BEHAVIOR option, is
   * executed in "standard snprintf behavior" and returns number of (wide)
   * chars required to allocate. For all other cases it is executed in a way
   * that returns negative value on error. But C95+ compliant vswprintf() for
   * case _Count == 0 returns negative value, so handle this case specially.
   */
  if (_Dest == NULL && _Count == 0)
    return -1;
  __ret = __stdio_common_vswprintf(_CRT_INTERNAL_LOCAL_PRINTF_OPTIONS, _Dest, _Count, _Format, NULL, _Args);
  return __ret < 0 ? -1 : __ret;
}
