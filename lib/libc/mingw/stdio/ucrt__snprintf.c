/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#undef __MSVCRT_VERSION__
#define _UCRT
#include <stdio.h>
#include <stdarg.h>

int __cdecl _snprintf(char * __restrict__ _Dest, size_t _Count, const char * __restrict__ _Format, ...)
{
  int ret;
  va_list _Args;
  va_start(_Args, _Format);
  ret = __stdio_common_vsprintf(_CRT_INTERNAL_LOCAL_PRINTF_OPTIONS | _CRT_INTERNAL_PRINTF_LEGACY_VSPRINTF_NULL_TERMINATION, _Dest, _Count, _Format, NULL, _Args);
  va_end(_Args);
  return ret;
}
