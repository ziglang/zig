/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <stdarg.h>
#include <stddef.h>

/* Intentionally not including stdio.h, as it unconditionally defines the
 * vsnprintf inline, and it can't be renamed with "#define vsnprintf othername"
 * either, as stdio.h contains "#undef vsnprintf". */

int __cdecl __ms_vsnprintf(char *buffer, size_t n, const char *format, va_list arg);

int __cdecl vsnprintf(char *buffer, size_t n, const char *format, va_list arg);
int __cdecl vsnprintf(char *buffer, size_t n, const char *format, va_list arg)
{
  return __ms_vsnprintf(buffer, n, format, arg);
}
