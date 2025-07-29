/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#undef __MSVCRT_VERSION__
#define _UCRT
#include <stdio.h>

int __cdecl swscanf(const wchar_t * __restrict__ _Src,const wchar_t * __restrict__ _Format,...) {
  __builtin_va_list __ap;
  int __ret;
  __builtin_va_start(__ap, _Format);
  __ret = __stdio_common_vswscanf(_CRT_INTERNAL_LOCAL_SCANF_OPTIONS, _Src, (size_t)-1, _Format, NULL, __ap);
  __builtin_va_end(__ap);
  return __ret;
}
