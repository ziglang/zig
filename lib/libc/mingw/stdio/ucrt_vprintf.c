/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#undef __MSVCRT_VERSION__
#define _UCRT
#include <stdio.h>

int __cdecl vprintf(const char * __restrict__ _Format,va_list _ArgList)
{
  return __stdio_common_vfprintf(0, stdout, _Format, NULL, _ArgList);
}
int __cdecl (*__MINGW_IMP_SYMBOL(vprintf))(const char *__restrict__, va_list) = vprintf;
