/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#undef __MSVCRT_VERSION__
#define _UCRT
#include <stdio.h>

int __cdecl vsscanf (const char * __restrict__ __source, const char * __restrict__ __format, __builtin_va_list __local_argv) {
  return __stdio_common_vsscanf(_CRT_INTERNAL_LOCAL_SCANF_OPTIONS, __source, (size_t)-1, __format, NULL, __local_argv);
}
