/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#undef __MSVCRT_VERSION__
#define _UCRT
#include <stdio.h>

int __cdecl vscanf(const char *__format, __builtin_va_list __local_argv) {
  return __stdio_common_vfscanf(_CRT_INTERNAL_LOCAL_SCANF_OPTIONS, stdin, __format, NULL, __local_argv);
}
