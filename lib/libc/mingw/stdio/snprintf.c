/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <stdarg.h>
#include <stdio.h>

int __cdecl __ms_snprintf(char* buffer, size_t n, const char *format, ...)
{
  int retval;
  va_list argptr;
         
  va_start(argptr, format);
  retval = __ms_vsnprintf(buffer, n, format, argptr);
  va_end(argptr);
  return retval;
}
