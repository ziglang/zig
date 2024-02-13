/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#undef __MSVCRT_VERSION__
#define _UCRT
#include <stdio.h>

int __cdecl snprintf (char * __restrict__ __stream, size_t __n, const char * __restrict__ __format, ...)
{
  __builtin_va_list ap;
  int ret;
  __builtin_va_start(ap, __format);
  ret = __stdio_common_vsprintf(_CRT_INTERNAL_PRINTF_STANDARD_SNPRINTF_BEHAVIOR, __stream, __n, __format, NULL, ap);
  __builtin_va_end(ap);
  return ret;
}
int __cdecl (*__MINGW_IMP_SYMBOL(snprintf))(char *__restrict__, size_t, const char *__restrict__, ...) = snprintf;
