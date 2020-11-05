/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <stdarg.h>
#include <stddef.h>

/* Intentionally not including stdio.h, as it unconditionally defines the
 * snprintf inline, and it can't be renamed with "#define snprintf othername"
 * either, as stdio.h contains "#undef snprintf". */

int __cdecl __ms_vsnprintf(char *buffer, size_t n, const char *format, va_list arg);

int __cdecl snprintf(char *buffer, size_t n, const char *format, ...);
int __cdecl snprintf(char *buffer, size_t n, const char *format, ...)
{
  int retval;
  va_list argptr;

  va_start(argptr, format);
  retval = __ms_vsnprintf(buffer, n, format, argptr);
  va_end(argptr);
  return retval;
}
