/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#undef __MSVCRT_VERSION__
#define _UCRT

#include <stdarg.h>
#include <stdio.h>

int __cdecl fwprintf(FILE *ptr, const wchar_t *fmt, ...);

int __cdecl fwprintf(FILE *ptr, const wchar_t *fmt, ...)
{
  va_list ap;
  int ret;
  va_start(ap, fmt);
  ret = __stdio_common_vfwprintf(_CRT_INTERNAL_LOCAL_PRINTF_OPTIONS, ptr, fmt, NULL, ap);
  va_end(ap);
  return ret;
}
