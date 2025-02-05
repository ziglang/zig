/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#undef __MSVCRT_VERSION__
#define _UCRT
#include <stdio.h>
#include <stdarg.h>

int __cdecl _snscanf(const char * __restrict__ _Src, size_t _MaxCount, const char * __restrict__ _Format, ...)
{
  int ret;
  va_list _ArgList;
  va_start(_ArgList, _Format);
  ret = __stdio_common_vsscanf(0, _Src, _MaxCount, _Format, NULL, _ArgList);
  va_end(_ArgList);
  return ret;
}
int __cdecl (*__MINGW_IMP_SYMBOL(_snscanf))(const char *__restrict__, size_t, const char * __restrict__, ...) = _snscanf;
