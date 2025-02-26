/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#undef __MSVCRT_VERSION__
#define _UCRT

#include <stdio.h>
#include <stdarg.h>

int __cdecl __ms_fprintf(FILE * restrict file, const char * restrict format, ...)
{
  va_list ap;
  int ret;
  va_start(ap, format);
  ret = __stdio_common_vfprintf(_CRT_INTERNAL_LOCAL_PRINTF_OPTIONS, file, format, NULL, ap);
  va_end(ap);
  return ret;
}
int __cdecl (*__MINGW_IMP_SYMBOL(__ms_fprintf))(FILE * restrict, const char * restrict, ...) = __ms_fprintf;
