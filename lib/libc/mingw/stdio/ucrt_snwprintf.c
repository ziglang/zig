/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#undef __MSVCRT_VERSION__
#define _UCRT
#include <stdio.h>

int __cdecl snwprintf (wchar_t * __restrict__ s, size_t n, const wchar_t * __restrict__ format, ...)
{
  __builtin_va_list __ap;
  int __ret;
  __builtin_va_start(__ap, format);
  __ret = __stdio_common_vswprintf(_CRT_INTERNAL_LOCAL_PRINTF_OPTIONS | _CRT_INTERNAL_PRINTF_STANDARD_SNPRINTF_BEHAVIOR, s, n, format, NULL, __ap);
  __builtin_va_end(__ap);
  return __ret;
}
